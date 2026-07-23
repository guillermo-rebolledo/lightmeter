import CoreGraphics

/// The pure geometry behind the linear ruler dial: it maps a drag to a continuous
/// dial position, rounds that to a real stop, and places evenly spaced ticks along
/// the ruler. No SwiftUI, gestures, or haptics — just the risky math, so it can be
/// unit-tested in isolation. Axis-agnostic (the dial is horizontal-only now, but
/// this is plain 1-D stop math with no orientation baked in).
///
/// Positions are expressed in stop-units: `0` is the first stop, `stopCount - 1`
/// the last. Offsets are measured along the ruler (x, since it is horizontal) from
/// the fixed indicator at its centre; positive offsets point toward higher-value
/// stops (right).
struct LinearDialGeometry {
    /// The distance (points) along the main axis of one stop: both the drag travel
    /// that advances the selection one stop and the gap between adjacent ticks. A
    /// single value keeps the two in lockstep, so the ruler tracks the finger 1:1 —
    /// the mark under your thumb stays under it as you sweep.
    let spacing: CGFloat

    /// The continuous dial position for a drag that began at `anchor`, clamped to
    /// `[0, stopCount - 1]`. Dragging back along the axis (negative `travel`)
    /// advances toward higher values, so one `spacing` of travel is one stop.
    func position(fromAnchor anchor: Int, travel: CGFloat, stopCount: Int) -> CGFloat {
        guard stopCount > 0 else { return 0 }
        let raw = CGFloat(anchor) - travel / spacing
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
        (CGFloat(index) - position) * spacing
    }

    /// The window of stop indices worth drawing: `span` stops either side of the
    /// current position, clamped to the scale's bounds. Empty for an empty scale or
    /// a negative span (which has no window to draw).
    func visibleIndices(around position: CGFloat, stopCount: Int, span: Int) -> [Int] {
        guard stopCount > 0, span >= 0 else { return [] }
        let center = min(max(stop(at: position), 0), stopCount - 1)
        let lower = max(center - span, 0)
        let upper = min(center + span, stopCount - 1)
        return Array(lower...upper)
    }
}
