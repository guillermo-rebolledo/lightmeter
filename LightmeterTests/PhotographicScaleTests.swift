import Testing
import Foundation
@testable import Lightmeter

/// Snapping arbitrary computed values to the real, dial-able stops of the
/// standard 1/3-stop scales — the property that makes a solved exposure settable
/// on a camera.
struct PhotographicScaleTests {
    // MARK: Identity

    @Test func snappingAStopReturnsItself() {
        #expect(PhotographicScale.aperture.snap(8).label == "8")
        #expect(PhotographicScale.iso.snap(400).label == "400")
        #expect(PhotographicScale.shutter.snap(1.0 / 125).label == "1/125")
    }

    // MARK: Nearest-in-stop-space

    @Test func apertureSnapsToNearestStop() {
        // 9.3 sits between f/9 and f/10, closer (in stops) to f/9.
        #expect(PhotographicScale.aperture.snap(9.3).value == 9.0)
    }

    @Test func isoSnapsToNearestStop() {
        // 430 is closer in stops to ISO 400 than to ISO 500.
        #expect(PhotographicScale.iso.snap(430).label == "400")
    }

    @Test func rawSolvedShutterSnapsToDialMark() {
        // A solved 1/137 s is not a real dial mark; it snaps to 1/125.
        #expect(PhotographicScale.shutter.snap(1.0 / 137).label == "1/125")
    }

    // MARK: Rounding boundaries

    /// Just above the stop-space midpoint between 1/160 and 1/125 rounds up to
    /// 1/125; just below rounds down to 1/160. This pins the rounding boundary.
    @Test func snappingRoundsAcrossTheStopMidpoint() {
        let geometricMidpoint = (1.0 / 160 * (1.0 / 125)).squareRoot()
        #expect(PhotographicScale.shutter.snap(geometricMidpoint * 1.01).label == "1/125")
        #expect(PhotographicScale.shutter.snap(geometricMidpoint * 0.99).label == "1/160")
    }

    // MARK: Clamping and defensive inputs

    @Test func outOfRangeValuesClampToTheNearestEndpoint() {
        #expect(PhotographicScale.aperture.snap(1000).value == 32)      // beyond f/32
        #expect(PhotographicScale.aperture.snap(0.5).value == 1.0)       // wider than f/1
        #expect(PhotographicScale.shutter.snap(120).label == "30\"")     // slower than 30 s
        #expect(PhotographicScale.shutter.snap(1.0 / 100000).label == "1/8000") // faster than 1/8000
    }

    @Test(arguments: [0.0, -1.0, Double.nan, Double.infinity])
    func nonPhysicalInputsFallBackToLowestStop(_ value: Double) {
        #expect(PhotographicScale.shutter.snap(value).value == PhotographicScale.shutter.stops[0].value)
    }

    // MARK: Scale integrity

    @Test func scalesAreAscendingByValue() {
        for scale in [PhotographicScale.iso, .aperture, .shutter] {
            let values = scale.stops.map(\.value)
            #expect(values == values.sorted())
        }
    }
}
