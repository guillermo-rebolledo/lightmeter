import CoreGraphics

/// The pure drag→value model behind the exposure-compensation track: it maps a
/// horizontal drag (and the vertical drift that came with it) to a bias value,
/// snaps that onto the third-stop detents compensation steps in, and places the
/// knob along the track. No SwiftUI, gestures, or haptics — just the risky math,
/// so the AC's "drag-to-value, clamping, detent snapping, and the
/// reduced-sensitivity rule" are all testable with no view in the way, exactly as
/// `LinearDialGeometry` is for the ruler.
///
/// Two facts about compensation are baked in here rather than drawn:
///
/// - **It steps in thirds of a stop regardless of the chosen stop increment.**
///   Cameras treat exposure bias independently of the aperture and shutter
///   detents, so the track's grid is always thirds — it does not follow
///   `StopIncrement` the way an exposure leg's scale does.
/// - **It is clamped to ±`extent`.** The same ±3-stop range
///   `MeterViewModel.setCompensation` already enforces, restated here so the knob
///   cannot be dragged past an end the solve would only clamp back from.
struct CompensationSlider: Equatable {
    /// The bias extent in stops: the track runs from `-extent` (left) to
    /// `+extent` (right). ±3, matching `MeterViewModel.setCompensation`'s clamp.
    let extent: Double

    /// The detent granularity in stops — a third — so the knob settles only on a
    /// value the solve treats as a real bias, and never between clicks.
    let step: Double

    /// The visible track's width in points. One full end-to-end sweep of the
    /// track (`2 * extent` stops) maps across it at a vertical distance of zero,
    /// which is what makes a drag along the track move the knob under the thumb.
    let trackWidth: CGFloat

    /// The vertical drift, in points, at which sensitivity has fallen to half —
    /// the knee of the reduced-sensitivity curve. This is what lets a short track
    /// still land a precise value: drop the thumb below (or above) the track and
    /// each point of horizontal travel buys less bias, so the last third is
    /// reachable without a hair-trigger track.
    let sensitivityFalloff: CGFloat

    init(
        extent: Double = 3,
        step: Double = 1.0 / 3,
        trackWidth: CGFloat,
        sensitivityFalloff: CGFloat = 44
    ) {
        self.extent = extent
        self.step = step
        self.trackWidth = trackWidth
        self.sensitivityFalloff = sensitivityFalloff
    }

    /// The full bias span the track covers, `2 * extent` stops.
    var span: Double { 2 * extent }

    /// The highest signed detent index either side of zero — `+9` / `-9` for
    /// ±3 stops in thirds. The clamp both `snap(_:)` and `detentIndex(for:)` land
    /// against.
    var maxDetentIndex: Int { Int((extent / step).rounded()) }

    /// The sensitivity multiplier for a vertical `distance` from the track: `1` on
    /// the track, falling toward `0` as the thumb drifts away and halving every
    /// `sensitivityFalloff` points. Always in `(0, 1]`, and monotonically
    /// decreasing in `abs(distance)` — the reduced-sensitivity rule, as a
    /// function so it can be asserted directly.
    func sensitivity(verticalDistance distance: CGFloat) -> CGFloat {
        guard sensitivityFalloff > 0 else { return 1 }
        return sensitivityFalloff / (sensitivityFalloff + abs(distance))
    }

    /// The continuous, clamped bias for a drag that began at `start`, given
    /// horizontal `translation` and its `verticalDistance` from the track.
    /// Positive translation (dragging the knob right) asks for more exposure. Not
    /// yet snapped — that is `snap(_:)` — so the view can slide the knob
    /// continuously and settle it onto a detent.
    func value(from start: Double, translation: CGFloat, verticalDistance: CGFloat) -> Double {
        guard trackWidth > 0 else { return clamp(start) }
        let stopsPerPoint = span / Double(trackWidth)
        let effective = translation * sensitivity(verticalDistance: verticalDistance)
        return clamp(start + Double(effective) * stopsPerPoint)
    }

    /// The nearest third-stop detent to `value`, clamped to the range — the real
    /// bias the knob settles on and the solve is handed.
    func snap(_ value: Double) -> Double {
        Double(detentIndex(for: value)) * step
    }

    /// The signed detent index (… −1, 0, +1 …) nearest `value`, clamped to the
    /// track's ends — what the view watches to fire one haptic per detent
    /// actually crossed, the way the ruler dial does.
    func detentIndex(for value: Double) -> Int {
        let raw = (clamp(value) / step).rounded()
        return min(max(Int(raw), -maxDetentIndex), maxDetentIndex)
    }

    /// The knob's position along the track as a fraction in `[0, 1]`: `0` at
    /// `-extent`, `0.5` at zero bias, `1` at `+extent`.
    func position(for value: Double) -> CGFloat {
        guard span > 0 else { return 0.5 }
        return CGFloat((clamp(value) + extent) / span)
    }

    private func clamp(_ value: Double) -> Double {
        min(max(value, -extent), extent)
    }
}
