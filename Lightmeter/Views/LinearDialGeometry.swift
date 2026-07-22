import CoreGraphics

/// The pure geometry behind the linear ruler dial: it maps a drag to a continuous
/// dial position, rounds that to a real stop, and places evenly spaced ticks along
/// the ruler's main axis. No SwiftUI, gestures, or haptics — just the risky math,
/// so it can be unit-tested in isolation.
///
/// Positions are expressed in stop-units: `0` is the first stop, `stopCount - 1`
/// the last. Offsets are measured along the ruler's main axis (x when the ruler is
/// horizontal, y when vertical) from the fixed indicator at its centre; positive
/// offsets point toward higher-value stops (right / down).
struct LinearDialGeometry {
    /// Drag distance (points) along the main axis that advances the dial one stop.
    let pointsPerStop: CGFloat
    /// Distance (points) between adjacent ticks along the main axis.
    let tickSpacing: CGFloat

    /// The continuous dial position for a drag that began at `anchor`, clamped to
    /// `[0, stopCount - 1]`. Dragging back along the axis (negative `travel`)
    /// advances toward higher values, so one `pointsPerStop` of travel is one stop.
    func position(fromAnchor anchor: Int, travel: CGFloat, stopCount: Int) -> CGFloat {
        guard stopCount > 0 else { return 0 }
        let raw = CGFloat(anchor) - travel / pointsPerStop
        return min(max(raw, 0), CGFloat(stopCount - 1))
    }

    /// The real, dial-able stop nearest a continuous position — the detent the dial
    /// settles on and reports up.
    func stop(at position: CGFloat) -> Int {
        Int(position.rounded())
    }

    /// The offset along the main axis, from the fixed indicator, of the tick for
    /// `index` at the given continuous `position`. At an integer position the
    /// selected tick sits on the indicator (offset `0`) and its neighbours fan out
    /// evenly and symmetrically either side.
    func tickOffset(for index: Int, position: CGFloat) -> CGFloat {
        (CGFloat(index) - position) * tickSpacing
    }

    /// The window of stop indices worth drawing: `span` stops either side of the
    /// current position, clamped to the scale's bounds. Empty for an empty scale.
    func visibleIndices(around position: CGFloat, stopCount: Int, span: Int) -> [Int] {
        guard stopCount > 0 else { return [] }
        let center = min(max(stop(at: position), 0), stopCount - 1)
        let lower = max(center - span, 0)
        let upper = min(center + span, stopCount - 1)
        return Array(lower...upper)
    }
}
