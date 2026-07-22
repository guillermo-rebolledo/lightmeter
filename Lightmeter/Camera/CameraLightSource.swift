import AVFoundation
import QuartzCore

// MARK: - CameraLightSource (AVFoundation adapter — the hand-validated edge)
//
// The production `LightSource`. It requests camera permission, configures a
// capture session on the rear wide-angle camera, runs continuous auto-exposure,
// and streams the AE metadata (ISO / exposureDuration / lensAperture) as
// `LightReading`s. The `ExposureEngine` turns those into EV@ISO100.
//
// This type is deliberately NOT unit-tested — mocking AVFoundation buys little
// and costs a lot. It is validated by hand on-device. The tested seam is
// `MeterViewModel`, driven by a fake `LightSource`.

final class CameraLightSource: NSObject, LightSource {
    /// The capture session backing the live preview. Exposed so the SwiftUI
    /// preview can bind an `AVCaptureVideoPreviewLayer` to it.
    let session = AVCaptureSession()

    /// The rear wide-angle camera, resolved once so the capture input and the
    /// preview's `RotationCoordinator` share a single device reference. `nil`
    /// where there's no rear camera (e.g. the Simulator), which leaves the
    /// session unconfigured and surfaces as capture being unavailable.
    let captureDevice = AVCaptureDevice.default(
        .builtInWideAngleCamera, for: .video, position: .back
    )

    private let sessionQueue = DispatchQueue(label: "com.lightmeter.camera.session")
    private let sampleQueue = DispatchQueue(label: "com.lightmeter.camera.samples")
    private let videoOutput = AVCaptureVideoDataOutput()
    private var sampler: ReadingSampler?
    private var isConfigured = false

    /// The capture device once configured, retained so the AE region of interest
    /// can be re-aimed for spot metering. Touched only on `sessionQueue`.
    private var device: AVCaptureDevice?

    /// The exposure point of interest to keep the device aimed at — center for
    /// whole-frame average, or the placed spot. Touched only on `sessionQueue`.
    private var exposurePoint = CGPoint.frameCenter

    /// The continuation for the current session's stream. Touched only on
    /// `sessionQueue`, so it needs no further synchronization here.
    private var activeContinuation: AsyncStream<LightReading>.Continuation?

    func requestAuthorization() async -> LightSourceAuthorization {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            return .authorized
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            return granted ? .authorized : .denied
        default:
            return .denied
        }
    }

    func start() -> AsyncStream<LightReading> {
        // Keep only the newest sample: the meter cares about "now", not a backlog.
        let (stream, continuation) = AsyncStream<LightReading>.makeStream(
            bufferingPolicy: .bufferingNewest(1)
        )

        sessionQueue.async { [weak self] in
            guard let self else {
                continuation.finish()
                return
            }
            self.configureIfNeeded()
            guard let sampler = self.sampler else {
                // Configuration failed (no camera / no input): finish immediately
                // so the consumer's `for await` completes rather than hanging.
                continuation.finish()
                return
            }
            // Defensive: if start() is called again without a matching stop(),
            // finish the prior session's stream so its consumer isn't left hanging.
            self.activeContinuation?.finish()
            self.activeContinuation = continuation
            sampler.setContinuation(continuation)
            if !self.session.isRunning {
                self.session.startRunning()
            }
        }

        return stream
    }

    func stop() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            if self.session.isRunning {
                self.session.stopRunning()
            }
            self.sampler?.setContinuation(nil)
            self.activeContinuation?.finish()
            self.activeContinuation = nil
        }
    }

    func setExposurePointOfInterest(_ point: CGPoint?) {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            // AVFoundation has no distinct whole-frame-average metering mode; the
            // only knob is the AE point of interest. Average (`nil`) aims it at
            // center for a center-weighted read — the closest the API gets to
            // "whole frame" — while spot aims it at the placed point.
            self.exposurePoint = point ?? .frameCenter
            self.configureIfNeeded()
            self.applyExposurePoint()
        }
    }

    // MARK: - Configuration

    /// Aims the device's continuous auto-exposure at `exposurePoint`. Runs on
    /// `sessionQueue`; a no-op until the device is configured or if the device
    /// doesn't support a settable point of interest.
    private func applyExposurePoint() {
        guard let device, device.isExposurePointOfInterestSupported else { return }
        guard (try? device.lockForConfiguration()) != nil else { return }
        device.exposurePointOfInterest = exposurePoint
        if device.isExposureModeSupported(.continuousAutoExposure) {
            device.exposureMode = .continuousAutoExposure
        }
        device.unlockForConfiguration()
    }

    private func configureIfNeeded() {
        guard !isConfigured else { return }

        session.beginConfiguration()
        defer { session.commitConfiguration() }
        session.sessionPreset = .high

        guard
            let device = captureDevice,
            let input = try? AVCaptureDeviceInput(device: device),
            session.canAddInput(input)
        else {
            return
        }
        session.addInput(input)
        self.device = device

        // Continuous auto-exposure so the streamed metadata tracks the live scene.
        if (try? device.lockForConfiguration()) != nil {
            if device.isExposureModeSupported(.continuousAutoExposure) {
                device.exposureMode = .continuousAutoExposure
            }
            device.unlockForConfiguration()
        }

        let sampler = ReadingSampler(device: device)
        self.sampler = sampler
        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.setSampleBufferDelegate(sampler, queue: sampleQueue)
        if session.canAddOutput(videoOutput) {
            session.addOutput(videoOutput)
        }

        isConfigured = true
        // Aim AE at the current point (center by default) now the device exists.
        applyExposurePoint()
    }
}

// MARK: - ReadingSampler

/// Reads the camera's live AE metadata off each video frame and yields a
/// throttled stream of `LightReading`s. Runs on the sample-buffer queue.
///
/// The target continuation is swapped between metering sessions via
/// `setContinuation(_:)` (called on the session queue) and read in the capture
/// callback (on the sample queue), so access is guarded by a lock.
private final class ReadingSampler: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    private let device: AVCaptureDevice
    private let lock = NSLock()
    private var continuation: AsyncStream<LightReading>.Continuation?

    private let minInterval: CFTimeInterval = 0.1
    private var lastEmit: CFTimeInterval = 0

    init(device: AVCaptureDevice) {
        self.device = device
    }

    /// Points the sampler at the current session's stream, or `nil` to stop
    /// emitting.
    func setContinuation(_ continuation: AsyncStream<LightReading>.Continuation?) {
        lock.lock()
        self.continuation = continuation
        lock.unlock()
    }

    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        let now = CACurrentMediaTime()
        guard now - lastEmit >= minInterval else { return }
        lastEmit = now

        let iso = Double(device.iso)
        let duration = CMTimeGetSeconds(device.exposureDuration)
        let aperture = Double(device.lensAperture)
        guard iso > 0, aperture > 0, duration > 0, duration.isFinite else { return }

        lock.lock()
        let continuation = self.continuation
        lock.unlock()
        continuation?.yield(
            LightReading(iso: iso, exposureDuration: duration, aperture: aperture)
        )
    }
}
