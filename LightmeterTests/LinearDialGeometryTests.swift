import Testing
import CoreGraphics
@testable import Lightmeter

/// The pure tick-placement and drag→stop math behind the linear ruler dial.
/// Extracted from the view so the risky geometry can be exercised in isolation,
/// with no SwiftUI, gestures, or haptics in the way.
struct LinearDialGeometryTests {
    private let spacing: CGFloat = 40
    private var geometry: LinearDialGeometry { LinearDialGeometry(spacing: spacing) }

    // MARK: - Drag → position

    @Test("One stop of drag advances the dial exactly one stop")
    func oneStopOfDragIsOneStop() {
        // Dragging back along the axis (negative travel) advances toward higher
        // values; one `spacing` of travel is one stop.
        let position = geometry.position(fromAnchor: 4, travel: -spacing, stopCount: 20)
        #expect(position == 5)

        let back = geometry.position(fromAnchor: 4, travel: spacing, stopCount: 20)
        #expect(back == 3)
    }

    @Test("One stop of drag slides tick offsets by exactly one spacing")
    func oneStopOfDragSlidesTicksOneSpacing() {
        // The drag scale and the tick spacing are one value, so the ruler tracks
        // the finger 1:1: dragging one stop moves every tick exactly one spacing.
        let atRest = (2...8).map { geometry.tickOffset(for: $0, position: 4) }
        let oneStopIn = geometry.position(fromAnchor: 4, travel: -spacing, stopCount: 20)
        let dragged = (2...8).map { geometry.tickOffset(for: $0, position: oneStopIn) }
        let shift = zip(atRest, dragged).map { $1 - $0 }
        #expect(shift.allSatisfy { abs($0 - -spacing) < 0.0001 })
    }

    @Test("A fractional drag yields a fractional, continuous position")
    func fractionalDragIsContinuous() {
        let position = geometry.position(fromAnchor: 4, travel: -spacing / 2, stopCount: 20)
        #expect(position == 4.5)
    }

    @Test("Positions clamp at both ends of the scale")
    func positionsClampAtBothEnds() {
        let overTop = geometry.position(fromAnchor: 18, travel: -1000, stopCount: 20)
        #expect(overTop == 19)

        let underBottom = geometry.position(fromAnchor: 2, travel: 1000, stopCount: 20)
        #expect(underBottom == 0)
    }

    // MARK: - Position → reported stop

    @Test("The reported stop is the rounded nearest detent")
    func reportedStopIsNearestDetent() {
        #expect(geometry.stop(at: 5.4) == 5)
        #expect(geometry.stop(at: 5.6) == 6)
        #expect(geometry.stop(at: 5.0) == 5)
    }

    // MARK: - Tick placement

    @Test("Tick offsets are evenly spaced")
    func tickOffsetsAreEvenlySpaced() {
        let offsets = (3...7).map { geometry.tickOffset(for: $0, position: 5) }
        let deltas = zip(offsets, offsets.dropFirst()).map { $1 - $0 }
        #expect(deltas.allSatisfy { $0 == 40 })
    }

    @Test("Tick offsets are symmetric about the selection")
    func tickOffsetsAreSymmetricAboutSelection() {
        // With the selection centred, a tick k stops above mirrors one k below.
        for k in 1...5 {
            let above = geometry.tickOffset(for: 10 + k, position: 10)
            let below = geometry.tickOffset(for: 10 - k, position: 10)
            #expect(above == -below)
        }
        // The selected tick itself sits exactly on the indicator.
        #expect(geometry.tickOffset(for: 10, position: 10) == 0)
    }

    @Test("A fractional position slides every tick by the same offset")
    func fractionalPositionSlidesTicksUniformly() {
        let atFive = (2...8).map { geometry.tickOffset(for: $0, position: 5) }
        let atHalf = (2...8).map { geometry.tickOffset(for: $0, position: 5.5) }
        // Advancing the position half a stop slides every tick the same half-stop
        // toward the low end (negative along the axis).
        let shift = zip(atFive, atHalf).map { $1 - $0 }
        #expect(shift.allSatisfy { abs($0 - -20) < 0.0001 })
    }

    // MARK: - Visible window

    @Test("The visible window spans the given span each side, clamped to bounds")
    func visibleWindowClampsToBounds() {
        #expect(geometry.visibleIndices(around: 10, stopCount: 20, span: 3) == Array(7...13))
        #expect(geometry.visibleIndices(around: 0, stopCount: 20, span: 3) == Array(0...3))
        #expect(geometry.visibleIndices(around: 19, stopCount: 20, span: 3) == Array(16...19))
    }

    @Test("An empty scale has no visible ticks")
    func emptyScaleHasNoTicks() {
        #expect(geometry.visibleIndices(around: 0, stopCount: 0, span: 3).isEmpty)
        #expect(geometry.position(fromAnchor: 0, travel: -100, stopCount: 0) == 0)
    }

    @Test("A negative span yields no ticks rather than trapping")
    func negativeSpanHasNoTicks() {
        // A negative span would make the lower bound exceed the upper and trap the
        // range; it must resolve to an empty window instead.
        #expect(geometry.visibleIndices(around: 10, stopCount: 20, span: -1).isEmpty)
    }
}
