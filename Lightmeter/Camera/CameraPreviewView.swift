import SwiftUI
import AVFoundation

/// Bridges the AVFoundation capture session into SwiftUI as a live preview, using
/// a `UIView` backed by an `AVCaptureVideoPreviewLayer`. This is the "hero" of the
/// meter screen.
///
/// It also owns spot-metering interaction: a tap converts the touch to a
/// normalized device point (via the preview layer) and reports it up, and a
/// reticle is drawn at the current spot while spot metering is active. Coordinate
/// conversion lives here because only the preview layer can map view points to the
/// camera's sensor space — the same reason this edge is hand-validated, not
/// unit-tested.
struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession

    /// The capture device feeding the session, used to build a
    /// `RotationCoordinator` so the preview connection tracks interface
    /// orientation and the scene stays upright as the device rotates. `nil`
    /// where there's no camera (e.g. the Simulator); rotation tracking is then
    /// simply inert.
    var captureDevice: AVCaptureDevice?

    /// The active spot as a normalized device point, or `nil` when none is placed
    /// — drives where the reticle is drawn.
    var spot: CGPoint?

    /// Whether spot metering is active — the reticle shows only then, and taps
    /// place a spot only then.
    var isSpotActive: Bool

    /// Called with the normalized device point when the photographer taps to place
    /// a spot.
    var onPlaceSpot: (CGPoint) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onPlaceSpot: onPlaceSpot, isSpotActive: isSpotActive)
    }

    func makeUIView(context: Context) -> PreviewView {
        #if DEBUG
        // #112: bracket makeUIView. The session is no longer attached here — that
        // is deferred until the session is running (see below) — so a stall between
        // these marks would be the view/rotation setup, not the attach.
        LaunchDiagnostics.mark(.previewAttachBegan)
        defer { LaunchDiagnostics.mark(.previewAttachEnded) }
        #endif
        let view = PreviewView()
        view.videoPreviewLayer.videoGravity = .resizeAspectFill

        let tap = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleTap(_:))
        )
        view.addGestureRecognizer(tap)

        // Drive the preview connection's rotation from the device's horizon-level
        // preview angle so the live scene stays upright as the device rotates.
        context.coordinator.startTrackingRotation(
            device: captureDevice,
            previewView: view
        )

        // Bind the session only once it is running (#112). A visible preview layer
        // attached to a still-starting session parks the main thread on the camera
        // pipeline until the first frame — the multi-second warmup stall that froze
        // the ruler — so the attach waits until frames are flowing.
        context.coordinator.attachSessionWhenRunning(session, to: view)
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {
        // Idempotent: attaches the session the first time it is running, and re-arms
        // only if the session identity changes. It never touches the layer's session
        // while it is still starting, keeping the render path off the capture lock
        // during warmup (#112).
        context.coordinator.attachSessionWhenRunning(session, to: uiView)
        context.coordinator.onPlaceSpot = onPlaceSpot
        context.coordinator.isSpotActive = isSpotActive
        uiView.updateReticle(devicePoint: spot, visible: isSpotActive)
    }

    /// Bridges the tap gesture to `onPlaceSpot`, converting the touch location to
    /// a normalized device point through the preview layer.
    final class Coordinator {
        var onPlaceSpot: (CGPoint) -> Void
        /// Whether spot metering is active — taps place a spot only then, so a
        /// stray tap in average mode can't silently switch the pattern. The
        /// metering-pattern toggle is the only control that changes the mode.
        var isSpotActive: Bool

        /// Tracks the device's physical orientation and publishes the rotation
        /// angle that keeps the preview horizon-level. Retained for the lifetime
        /// of the preview so its KVO keeps firing.
        private var rotationCoordinator: AVCaptureDevice.RotationCoordinator?
        private var rotationObservation: NSKeyValueObservation?

        /// Observes `session.isRunning` so the preview layer's session is attached
        /// only once frames are flowing (#112). Retained until the attach happens,
        /// then released.
        private var runningObservation: NSKeyValueObservation?

        init(onPlaceSpot: @escaping (CGPoint) -> Void, isSpotActive: Bool) {
            self.onPlaceSpot = onPlaceSpot
            self.isSpotActive = isSpotActive
        }

        /// Attaches `session` to the preview layer, but only once the session is
        /// running. A visible preview layer bound to a still-starting session makes
        /// the main thread wait on the camera pipeline until the first frame — the
        /// #112 warmup stall that froze the ruler for seconds. Deferring the attach
        /// until frames flow lets the preview light up without parking the main
        /// thread. Idempotent: a no-op once attached, and it re-arms the observation
        /// only while the session is not yet running.
        func attachSessionWhenRunning(_ session: AVCaptureSession, to previewView: PreviewView) {
            guard previewView.videoPreviewLayer.session !== session else { return }
            if session.isRunning {
                attach(session, to: previewView)
                return
            }
            // `isRunning` flips on the session queue when `startRunning()` returns;
            // hop to main for the CALayer mutation.
            runningObservation = session.observe(\.isRunning, options: [.new]) { [weak self, weak previewView] session, _ in
                guard session.isRunning, let self, let previewView else { return }
                DispatchQueue.main.async { self.attach(session, to: previewView) }
            }
        }

        private func attach(_ session: AVCaptureSession, to previewView: PreviewView) {
            guard previewView.videoPreviewLayer.session !== session else { return }
            runningObservation = nil
            #if DEBUG
            LaunchDiagnostics.measureMainThread("attachSession") {
                previewView.videoPreviewLayer.session = session
            }
            #else
            previewView.videoPreviewLayer.session = session
            #endif
            // The layer's connection only exists once the session is attached, so
            // the rotation observation's `.initial` fire (in makeUIView, before this)
            // had no connection to rotate. Apply the current horizon-level angle now
            // so the preview starts upright without waiting for a device rotation.
            if let angle = rotationCoordinator?.videoRotationAngleForHorizonLevelPreview {
                Self.applyRotation(angle, to: previewView.videoPreviewLayer)
                previewView.refreshReticle()
            }
        }

        /// Begins driving the preview connection's rotation from the device's
        /// horizon-level preview angle. `.initial` applies the current angle up
        /// front, then each subsequent orientation change flows through KVO. The
        /// AVFoundation-managed rotation is what keeps `captureDevicePointConverted`
        /// mapping taps correctly after a rotation, so spot metering stays aligned.
        func startTrackingRotation(
            device: AVCaptureDevice?,
            previewView: PreviewView
        ) {
            // No device (e.g. the Simulator) means no preview to keep upright.
            guard let device else { return }
            let coordinator = AVCaptureDevice.RotationCoordinator(
                device: device, previewLayer: previewView.videoPreviewLayer
            )
            rotationCoordinator = coordinator
            rotationObservation = coordinator.observe(
                \.videoRotationAngleForHorizonLevelPreview,
                options: [.initial, .new]
            ) { [weak previewView] observed, _ in
                guard let previewView else { return }
                Self.applyRotation(
                    observed.videoRotationAngleForHorizonLevelPreview,
                    to: previewView.videoPreviewLayer
                )
                // The new connection angle remaps device points to layer points,
                // so re-pin the reticle now rather than waiting for the next
                // layout pass — the view's bounds don't change on rotation while
                // the app is orientation-locked, so no layout pass is guaranteed.
                previewView.refreshReticle()
            }
        }

        /// Applies `angle` to the preview connection when supported. The preview
        /// layer's own connection is the only one touched here — capture-output
        /// rotation is a separate concern owned elsewhere.
        private static func applyRotation(
            _ angle: CGFloat,
            to previewLayer: AVCaptureVideoPreviewLayer
        ) {
            guard let connection = previewLayer.connection,
                  connection.isVideoRotationAngleSupported(angle)
            else { return }
            // Snap to the new angle: without disabling actions the preview would
            // visibly spin through a default CALayer animation on each rotation.
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            connection.videoRotationAngle = angle
            CATransaction.commit()
        }

        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard isSpotActive else { return }
            guard let view = gesture.view as? PreviewView else { return }
            let layerPoint = gesture.location(in: view)
            let devicePoint = view.videoPreviewLayer.captureDevicePointConverted(
                fromLayerPoint: layerPoint
            )
            onPlaceSpot(devicePoint)
        }
    }

    /// A `UIView` whose backing layer is the preview layer, so the layer resizes
    /// automatically with the view. Hosts the spot reticle and keeps it glued to
    /// its device point across layout changes.
    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }

        var videoPreviewLayer: AVCaptureVideoPreviewLayer {
            // Safe: `layerClass` guarantees the backing layer's type.
            layer as! AVCaptureVideoPreviewLayer
        }

        private let reticle = ReticleView()

        /// The device point the reticle is pinned to (normalized), reconverted to
        /// a layer point on every layout so it tracks the metered spot.
        private var reticleDevicePoint = CGPoint.frameCenter

        override init(frame: CGRect) {
            super.init(frame: frame)
            reticle.isHidden = true
            addSubview(reticle)
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        /// Pins the reticle to `devicePoint` (or center when `nil`) and shows it
        /// only while spot metering is `visible`.
        func updateReticle(devicePoint: CGPoint?, visible: Bool) {
            reticleDevicePoint = devicePoint ?? .frameCenter
            reticle.isHidden = !visible
            positionReticle()
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            positionReticle()
        }

        /// Re-pins the reticle to its device point after the preview connection's
        /// rotation changes — that remaps device points to layer points without
        /// necessarily triggering a layout pass.
        func refreshReticle() {
            positionReticle()
        }

        private func positionReticle() {
            guard !reticle.isHidden else { return }
            reticle.center = videoPreviewLayer.layerPointConverted(
                fromCaptureDevicePoint: reticleDevicePoint
            )
        }
    }
}

/// The spot-metering reticle: the handoff's small circle with a white rim and an
/// accent centre dot, marking the point the meter is reading.
///
/// It carries no reading of its own since #96. EV is the headline of the bar at
/// the top of the screen, so a badge here would be the same number twice — and
/// the reticle's job was never to be a readout. Showing it *only* in spot
/// metering is the other half of the same honesty: a point reticle drawn over a
/// whole-frame average claims a measurement that was not made.
private final class ReticleView: UIView {
    /// The circle's dimensions, shared with the design harness' SwiftUI stand-in
    /// so the two drawings of one reticle cannot drift apart.
    private static let diameter = ReticleGeometry.diameter
    private let rim = CAShapeLayer()
    private let dot = CAShapeLayer()

    init() {
        super.init(frame: CGRect(x: 0, y: 0, width: Self.diameter, height: Self.diameter))
        isUserInteractionEnabled = false

        let bounds = CGRect(x: 0, y: 0, width: Self.diameter, height: Self.diameter)
        let inset = ReticleGeometry.rimWidth / 2
        rim.path = UIBezierPath(ovalIn: bounds.insetBy(dx: inset, dy: inset)).cgPath
        rim.strokeColor = UIColor.white.withAlphaComponent(ReticleGeometry.rimOpacity).cgColor
        rim.fillColor = UIColor.clear.cgColor
        rim.lineWidth = ReticleGeometry.rimWidth
        // A white hairline vanishes against a blown-out sky; the drop shadow is
        // what keeps the rim findable over the scene's brightest part.
        rim.shadowColor = UIColor.black.cgColor
        rim.shadowOpacity = 0.6
        rim.shadowRadius = 3
        rim.shadowOffset = .zero
        layer.addSublayer(rim)

        let center = CGPoint(x: Self.diameter / 2, y: Self.diameter / 2)
        dot.path = UIBezierPath(
            arcCenter: center,
            radius: ReticleGeometry.dotRadius,
            startAngle: 0,
            endAngle: .pi * 2,
            clockwise: true
        ).cgPath
        dot.fillColor = UIColor.appAccent.cgColor
        layer.addSublayer(dot)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
