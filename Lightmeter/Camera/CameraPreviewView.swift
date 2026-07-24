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
        // #112: bracket the main-thread preview-layer attach — assigning the
        // session and standing up the `RotationCoordinator`, both on this first
        // layout pass. It is the one warmup suspect that runs on main, so a stall
        // the watchdog reports between these two marks is the swallowed-touch
        // window pinned to *this* step rather than to session start (off main) or
        // first-frame delivery. Inert unless launched with `-launch-diagnostics`.
        LaunchDiagnostics.mark(.previewAttachBegan)
        defer { LaunchDiagnostics.mark(.previewAttachEnded) }
        #endif
        let view = PreviewView()
        view.videoPreviewLayer.session = session
        view.videoPreviewLayer.videoGravity = .resizeAspectFill

        let tap = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleTap(_:))
        )
        view.addGestureRecognizer(tap)

        // Drive the preview connection's rotation from the device's horizon-level
        // preview angle so the live scene stays upright as the device rotates.
        // The session is already attached, so the layer's connection exists.
        context.coordinator.startTrackingRotation(
            device: captureDevice,
            previewView: view
        )
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {
        // Only (re)attach the session when it actually changed. This runs on every
        // SwiftUI update — and there are many during warmup — so re-assigning the
        // same session each time is wasted work at best. At worst it touches the
        // capture session's lock while `startRunning()` holds it on the session
        // queue, which is where #112 caught the main thread blocking for ~2.4s
        // during warmup, freezing the ruler. Assigning only on a real change keeps
        // the render path off that lock once the session is attached.
        if uiView.videoPreviewLayer.session !== session {
            #if DEBUG
            LaunchDiagnostics.measureMainThread("updateUIView.session") {
                uiView.videoPreviewLayer.session = session
            }
            #else
            uiView.videoPreviewLayer.session = session
            #endif
        }
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

        init(onPlaceSpot: @escaping (CGPoint) -> Void, isSpotActive: Bool) {
            self.onPlaceSpot = onPlaceSpot
            self.isSpotActive = isSpotActive
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
