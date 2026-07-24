import CoreGraphics

/// The spot reticle's shape, as numbers rather than as a drawing.
///
/// The reticle is drawn twice: by `ReticleView` in UIKit, because only the
/// preview layer can map a normalized device point to a layer point, and by the
/// design harness in SwiftUI, because in the Simulator there is no preview layer
/// to map through. Two drawings of one reticle is a standing invitation to drift
/// — and the thing that drifts is exactly what design decisions get judged from.
///
/// So the *geometry* lives here once and both renderers read it. Each still owns
/// its own stroking, since a `CAShapeLayer` and a SwiftUI view want different
/// primitives, but neither owns a dimension.
///
/// Since #96 it is a **circle** rather than the tap-to-focus corner brackets, and
/// it carries no reading of its own: EV is the headline of the bar at the top of
/// the screen, and the reticle is back to marking a point.
enum ReticleGeometry {
    /// The circle's diameter — the handoff's 64pt.
    static let diameter: CGFloat = 64

    /// The rim's stroke width and its opacity against the scene. White rather
    /// than accent, so the reticle reads as a marker on the frame rather than as
    /// one more accented value.
    ///
    /// The handoff's `1px rgba(255,255,255,.4)`, opened up: over the harness'
    /// blown window a 0.4 white hairline is invisible, which is exactly the
    /// failure the stand-in scenes exist to catch. The rim carries a drop shadow
    /// in both renderers for the same reason.
    static let rimWidth: CGFloat = 1.5
    static let rimOpacity: CGFloat = 0.75

    /// The centre dot's radius. Accent, and the only accent in the frame — this
    /// is the point being measured.
    static let dotRadius: CGFloat = 2.5
}
