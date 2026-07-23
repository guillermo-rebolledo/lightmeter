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

    /// The EV readout to badge the reticle with, or `nil` when EV isn't riding
    /// the reticle (average metering, no placed spot, or no reading yet). The
    /// whole readout rather than its string so the badge speaks the same
    /// label/value VoiceOver gets everywhere else; only its `badgeValue` shows.
    var evReadout: PreviewEVReadout?

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
            previewView: view
        )
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {
        uiView.videoPreviewLayer.session = session
        context.coordinator.onPlaceSpot = onPlaceSpot
        context.coordinator.isSpotActive = isSpotActive
        uiView.updateReticle(devicePoint: spot, visible: isSpotActive, badge: evReadout)
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
        /// only while spot metering is `visible`, carrying `badge`'s EV reading
        /// inline when there is one to show.
        func updateReticle(devicePoint: CGPoint?, visible: Bool, badge: PreviewEVReadout?) {
            reticleDevicePoint = devicePoint ?? .frameCenter
            reticle.isHidden = !visible
            reticle.showBadge(badge)
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

/// The spot-metering reticle: a tap-to-focus-style square with corner-only ticks
/// and a center dot, tinted to match the meter's accent, carrying the metered
/// point's EV as an inline badge beneath it.
///
/// The badge lives here, in UIKit, rather than as a SwiftUI overlay because only
/// the preview layer can map the spot's normalized device point to a layer point
/// — riding the reticle is what keeps EV glued to the tone it describes across
/// layout and rotation.
private final class ReticleView: UIView {
    /// The bracket's dimensions, shared with the design harness' SwiftUI
    /// stand-in so the two drawings of one reticle cannot drift apart.
    private static let side = ReticleGeometry.side
    private static let badgeGap = ReticleGeometry.badgeGap
    private let shape = CAShapeLayer()
    private let dot = CAShapeLayer()
    private let badge = ReticleBadgeLabel()

    init() {
        super.init(frame: CGRect(x: 0, y: 0, width: Self.side, height: Self.side))
        isUserInteractionEnabled = false
        // The badge hangs below the bracket, outside these bounds.
        clipsToBounds = false
        addSubview(badge)

        let accent = UIColor.appAccent.cgColor
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

        let dotRadius = ReticleGeometry.dotRadius
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

    /// Shows `readout`'s EV inline under the bracket, or hides the badge when
    /// there is no reading to attribute to this point.
    func showBadge(_ readout: PreviewEVReadout?) {
        guard let readout, let value = readout.badgeValue else {
            badge.isHidden = true
            return
        }
        badge.isHidden = false
        badge.text = value
        // Named and valued explicitly: read as its own text the badge would say
        // "E V 12.3" with no hint of *which* read it describes. The reticle
        // itself stays silent — it is decoration around this element.
        badge.isAccessibilityElement = true
        badge.accessibilityLabel = readout.accessibilityLabel
        badge.accessibilityValue = readout.accessibilityValue
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let size = badge.intrinsicContentSize
        badge.frame = CGRect(
            x: (Self.side - size.width) / 2,
            y: Self.side + Self.badgeGap,
            width: size.width,
            height: size.height
        )
    }

    /// Four L-shaped corner brackets inset within a `side × side` square, stroked
    /// from the shared `ReticleGeometry` polylines.
    private static func bracketPath(side: CGFloat) -> CGPath {
        let path = UIBezierPath()
        for corner in ReticleGeometry.bracketPolylines(side: side) {
            guard let start = corner.first else { continue }
            path.move(to: start)
            for point in corner.dropFirst() {
                path.addLine(to: point)
            }
        }
        return path.cgPath
    }
}

/// The reticle's inline EV badge: the metered point's reading on a small dark
/// capsule, sized to its own text.
///
/// It floats on the raw scene, which can be a blown-out sky, so it carries the
/// same kind of legibility scrim the pills and the HUD drawer do rather than
/// relying on white-on-nothing. Digits are monospaced so a live-updating reading
/// doesn't jitter the capsule's width under the photographer's eye.
private final class ReticleBadgeLabel: UILabel {
    /// Padding around the text, applied both to the drawn text and to the
    /// intrinsic size so the capsule is never tighter than what it draws.
    private static let insets = UIEdgeInsets(top: 3, left: 8, bottom: 3, right: 8)

    init() {
        super.init(frame: .zero)
        isHidden = true
        textColor = .white
        // Matched to the scrim the floating pills use over the same preview.
        backgroundColor = UIColor.black.withAlphaComponent(0.55)
        textAlignment = .center
        font = Self.badgeFont
        adjustsFontForContentSizeCategory = true
        layer.masksToBounds = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var intrinsicContentSize: CGSize {
        let size = super.intrinsicContentSize
        return CGSize(
            width: size.width + Self.insets.left + Self.insets.right,
            height: size.height + Self.insets.top + Self.insets.bottom
        )
    }

    override func drawText(in rect: CGRect) {
        super.drawText(in: rect.inset(by: Self.insets))
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        layer.cornerRadius = bounds.height / 2
    }

    /// The meter's rounded, monospaced-digit face, scaled with Dynamic Type but
    /// capped: the badge annotates a point in the frame, so at the accessibility
    /// sizes it grows to stay readable without covering the scene it describes.
    private static let badgeFont: UIFont = {
        let base = UIFont.monospacedDigitSystemFont(ofSize: 13, weight: .semibold)
        let rounded = base.fontDescriptor.withDesign(.rounded)
            .map { UIFont(descriptor: $0, size: base.pointSize) } ?? base
        return UIFontMetrics(forTextStyle: .caption1)
            .scaledFont(for: rounded, maximumPointSize: 22)
    }()
}
