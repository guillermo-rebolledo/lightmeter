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

    private let sessionQueue = DispatchQueue(label: "com.lightmeter.camera.session")
    private let sampleQueue = DispatchQueue(label: "com.lightmeter.camera.samples")
    private let videoOutput = AVCaptureVideoDataOutput()
    private var sampler: ReadingSampler?
    private var isConfigured = false

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

    // MARK: - Configuration

    private func configureIfNeeded() {
        guard !isConfigured else { return }

        session.beginConfiguration()
        defer { session.commitConfiguration() }
        session.sessionPreset = .high

        guard
            let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
            let input = try? AVCaptureDeviceInput(device: device),
            session.canAddInput(input)
        else {
            return
        }
        session.addInput(input)

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
