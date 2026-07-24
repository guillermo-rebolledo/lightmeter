import Testing
import CoreGraphics
@testable import Lightmeter

/// The pure drag→value math behind the exposure-compensation track. Extracted
/// from the view so the AC's four risky rules — drag-to-value, clamping, detent
/// snapping, and the reduced-sensitivity curve — are exercised with no SwiftUI,
/// gestures, or haptics anywhere in reach.
struct CompensationSliderTests {
    /// A track the width of a realistic panel row, in the shipped ±3-in-thirds
    /// configuration.
    private let trackWidth: CGFloat = 300
    private var slider: CompensationSlider {
        CompensationSlider(trackWidth: trackWidth)
    }

    // MARK: - Drag → value

    @Test("A drag across the whole track sweeps the whole ±3 range")
    func fullTrackDragIsFullRange() {
        // On the track (no vertical drift), one track-width of travel is the whole
        // span, so the knob tracks the thumb 1:1 along it.
        let toTop = slider.value(from: 0, translation: trackWidth / 2, verticalDistance: 0)
        #expect(abs(toTop - 3) < 1e-9)

        let toBottom = slider.value(from: 0, translation: -trackWidth / 2, verticalDistance: 0)
        #expect(abs(toBottom - -3) < 1e-9)
    }

    @Test("Dragging the knob right asks for more exposure")
    func draggingRightIncreasesBias() {
        // A quarter of the track from centre is a quarter of the span, +1.5 stops.
        let value = slider.value(from: 0, translation: trackWidth / 4, verticalDistance: 0)
        #expect(abs(value - 1.5) < 1e-9)
    }

    @Test("A drag is measured from where it began, not from zero")
    func dragIsRelativeToItsStart() {
        // Starting at +1 and dragging a sixth of the track (+1 stop) lands at +2.
        let value = slider.value(from: 1, translation: trackWidth / 6, verticalDistance: 0)
        #expect(abs(value - 2) < 1e-9)
    }

    // MARK: - Clamping

    @Test("The continuous value clamps to the ±3 ends")
    func valueClampsToRange() {
        #expect(slider.value(from: 0, translation: trackWidth * 5, verticalDistance: 0) == 3)
        #expect(slider.value(from: 0, translation: -trackWidth * 5, verticalDistance: 0) == -3)
        // A start already off the end is pulled back onto it.
        #expect(slider.value(from: 99, translation: 0, verticalDistance: 0) == 3)
    }

    @Test("A zero-width track cannot move or overflow the value")
    func zeroWidthTrackIsInert() {
        let degenerate = CompensationSlider(trackWidth: 0)
        #expect(degenerate.value(from: 1, translation: 500, verticalDistance: 0) == 1)
    }

    // MARK: - Detent snapping

    @Test("Snapping lands on the nearest third-stop detent, clamped")
    func snapLandsOnThirds() {
        #expect(abs(slider.snap(0.30) - 1.0 / 3) < 1e-9)   // 0.30 is nearest to 1/3
        #expect(abs(slider.snap(0.10) - 0.0) < 1e-9)       // 0.10 is nearest to 0
        #expect(abs(slider.snap(0.5) - 2.0 / 3) < 1e-9)    // halfway rounds up to 2/3
        #expect(slider.snap(2.95) == slider.snap(3.5))     // both clamp to the +3 end
    }

    @Test("Compensation steps in thirds whatever the exposure increment is")
    func detentGridIsAlwaysThirds() {
        // 3 stops of extent over the 19 thirds detents (−9 … +9): the grid is a
        // property of the slider, not of any `StopIncrement`.
        #expect(slider.maxDetentIndex == 9)
        #expect(slider.detentIndex(for: 1.0) == 3)
        #expect(slider.detentIndex(for: -1.0) == -3)
        // The extreme thirds snap exactly to ±3.
        #expect(slider.snap(3) == 3)
        #expect(slider.snap(-3) == -3)
    }

    @Test("Detent index counts one click per third crossed")
    func detentIndexCountsClicks() {
        // Sweeping from −3 to +3 passes 18 detents — one haptic per third.
        let low = slider.detentIndex(for: -3)
        let high = slider.detentIndex(for: 3)
        #expect(high - low == 18)
    }

    // MARK: - Reduced sensitivity

    @Test("Sensitivity is full on the track and falls with vertical distance")
    func sensitivityFallsWithDistance() {
        #expect(slider.sensitivity(verticalDistance: 0) == 1)

        // Monotonically decreasing in |distance|, and symmetric above / below.
        let near = slider.sensitivity(verticalDistance: 20)
        let far = slider.sensitivity(verticalDistance: 120)
        #expect(near > far)
        #expect(far > 0)
        #expect(slider.sensitivity(verticalDistance: -50) == slider.sensitivity(verticalDistance: 50))
    }

    @Test("Sensitivity halves at the falloff distance")
    func sensitivityHalvesAtFalloff() {
        let slider = CompensationSlider(trackWidth: trackWidth, sensitivityFalloff: 44)
        #expect(abs(slider.sensitivity(verticalDistance: 44) - 0.5) < 1e-9)
    }

    @Test("The same horizontal travel moves the value less when the thumb drifts off the track")
    func driftMakesTheDragFiner() {
        // The precise-adjustment guarantee: a short track still reaches a fine
        // value because pulling the thumb away slows the sweep.
        let onTrack = slider.value(from: 0, translation: 60, verticalDistance: 0)
        let drifted = slider.value(from: 0, translation: 60, verticalDistance: 100)
        #expect(drifted < onTrack)
        #expect(drifted > 0)
    }

    // MARK: - Knob placement

    @Test("The knob sits left at −3, centre at 0, right at +3")
    func knobPositionSpansTheTrack() {
        #expect(slider.position(for: -3) == 0)
        #expect(slider.position(for: 0) == 0.5)
        #expect(slider.position(for: 3) == 1)
        // Out-of-range values clamp onto the ends rather than running off.
        #expect(slider.position(for: 9) == 1)
    }
}
