import CoreGraphics

/// The spot reticle's shape, as numbers rather than as a drawing.
///
/// The reticle is drawn twice: by `ReticleView` in UIKit, because only the
/// preview layer can map a normalized device point to a layer point, and by the
/// design harness in SwiftUI, because in the Simulator there is no preview layer
/// to map through. Two drawings of one bracket is a standing invitation to drift
/// — and the thing that drifts is exactly what design decisions get judged from.
///
/// So the *geometry* lives here once and both renderers read it. Each still owns
/// its own stroking, since a `CAShapeLayer` and a SwiftUI `Shape` want different
/// path types, but neither owns a dimension.
enum ReticleGeometry {
    /// The bracket's side length.
    static let side: CGFloat = 78

    /// The gap between the bracket and the EV badge hanging beneath it — clears
    /// the bracket without drifting far from the point it annotates.
    static let badgeGap: CGFloat = 6

    /// The centre dot's radius.
    static let dotRadius: CGFloat = 2

    /// How far the bracket's stroke sits inside its own bounds.
    private static let inset: CGFloat = 2

    /// Each corner tick's length, as a fraction of the side.
    private static let tickRatio: CGFloat = 0.22

    /// The four L-shaped corner brackets, as open polylines in a `side × side`
    /// square. Each inner array is one corner, to be stroked as a connected run.
    static func bracketPolylines(side: CGFloat = side) -> [[CGPoint]] {
        let tick = side * tickRatio
        let lo = inset
        let hi = side - inset

        return [
            // Top-left
            [CGPoint(x: lo, y: lo + tick), CGPoint(x: lo, y: lo), CGPoint(x: lo + tick, y: lo)],
            // Top-right
            [CGPoint(x: hi - tick, y: lo), CGPoint(x: hi, y: lo), CGPoint(x: hi, y: lo + tick)],
            // Bottom-right
            [CGPoint(x: hi, y: hi - tick), CGPoint(x: hi, y: hi), CGPoint(x: hi - tick, y: hi)],
            // Bottom-left
            [CGPoint(x: lo + tick, y: hi), CGPoint(x: lo, y: hi), CGPoint(x: lo, y: hi - tick)],
        ]
    }
}
