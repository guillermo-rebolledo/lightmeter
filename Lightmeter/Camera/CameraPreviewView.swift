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
            previewLayer: view.videoPreviewLayer
        )
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {
        uiView.videoPreviewLayer.session = session
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

        /// Begins driving `previewLayer`'s connection rotation from the device's
        /// horizon-level preview angle. `.initial` applies the current angle up
        /// front, then each subsequent orientation change flows through KVO. The
        /// AVFoundation-managed rotation is what keeps `captureDevicePointConverted`
        /// mapping taps correctly after a rotation, so spot metering stays aligned.
        func startTrackingRotation(
            device: AVCaptureDevice?,
            previewLayer: AVCaptureVideoPreviewLayer
        ) {
            // No device (e.g. the Simulator) means no preview to keep upright.
            guard let device else { return }
            let coordinator = AVCaptureDevice.RotationCoordinator(
                device: device, previewLayer: previewLayer
            )
            rotationCoordinator = coordinator
            rotationObservation = coordinator.observe(
                \.videoRotationAngleForHorizonLevelPreview,
                options: [.initial, .new]
            ) { [weak previewLayer] observed, _ in
                guard let previewLayer else { return }
                Self.applyRotation(
                    observed.videoRotationAngleForHorizonLevelPreview,
                    to: previewLayer
                )
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

        private func positionReticle() {
            guard !reticle.isHidden else { return }
            reticle.center = videoPreviewLayer.layerPointConverted(
                fromCaptureDevicePoint: reticleDevicePoint
            )
        }
    }
}

/// The spot-metering reticle: a tap-to-focus-style square with corner-only ticks
/// and a center dot, tinted to match the meter's accent.
private final class ReticleView: UIView {
    private static let side: CGFloat = 78
    private let shape = CAShapeLayer()
    private let dot = CAShapeLayer()

    init() {
        super.init(frame: CGRect(x: 0, y: 0, width: Self.side, height: Self.side))
        isUserInteractionEnabled = false

        let accent = UIColor.systemYellow.cgColor
        shape.path = Self.bracketPath(side: Self.side)
        shape.strokeColor = accent
        shape.fillColor = UIColor.clear.cgColor
        shape.lineWidth = 2
        shape.lineCap = .round
        shape.shadowColor = UIColor.black.cgColor
        shape.shadowOpacity = 0.4
        shape.shadowRadius = 2
        shape.shadowOffset = .zero
        layer.addSublayer(shape)

        let dotRadius: CGFloat = 2
        let center = CGPoint(x: Self.side / 2, y: Self.side / 2)
        dot.path = UIBezierPath(
            arcCenter: center,
            radius: dotRadius,
            startAngle: 0,
            endAngle: .pi * 2,
            clockwise: true
        ).cgPath
        dot.fillColor = accent
        layer.addSublayer(dot)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Four L-shaped corner brackets inset within a `side × side` square.
    private static func bracketPath(side: CGFloat) -> CGPath {
        let path = UIBezierPath()
        let inset: CGFloat = 2
        let tick = side * 0.22
        let lo = inset
        let hi = side - inset

        // Top-left
        path.move(to: CGPoint(x: lo, y: lo + tick)); path.addLine(to: CGPoint(x: lo, y: lo)); path.addLine(to: CGPoint(x: lo + tick, y: lo))
        // Top-right
        path.move(to: CGPoint(x: hi - tick, y: lo)); path.addLine(to: CGPoint(x: hi, y: lo)); path.addLine(to: CGPoint(x: hi, y: lo + tick))
        // Bottom-right
        path.move(to: CGPoint(x: hi, y: hi - tick)); path.addLine(to: CGPoint(x: hi, y: hi)); path.addLine(to: CGPoint(x: hi - tick, y: hi))
        // Bottom-left
        path.move(to: CGPoint(x: lo + tick, y: hi)); path.addLine(to: CGPoint(x: lo, y: hi)); path.addLine(to: CGPoint(x: lo, y: hi - tick))

        return path.cgPath
    }
}
