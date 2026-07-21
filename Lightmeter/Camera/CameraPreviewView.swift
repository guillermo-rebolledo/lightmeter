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
        Coordinator(onPlaceSpot: onPlaceSpot)
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
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {
        uiView.videoPreviewLayer.session = session
        context.coordinator.onPlaceSpot = onPlaceSpot
        uiView.updateReticle(devicePoint: spot, visible: isSpotActive)
    }

    /// Bridges the tap gesture to `onPlaceSpot`, converting the touch location to
    /// a normalized device point through the preview layer.
    final class Coordinator {
        var onPlaceSpot: (CGPoint) -> Void

        init(onPlaceSpot: @escaping (CGPoint) -> Void) {
            self.onPlaceSpot = onPlaceSpot
        }

        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
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
