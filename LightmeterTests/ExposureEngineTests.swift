import Testing
import Foundation
@testable import Lightmeter

/// The pure metadata → EV@ISO100 conversion, checked against reference exposures.
///
/// EV@ISO100 = log2(N²/t) − log2(ISO/100)
struct ExposureEngineTests {
    /// Sunny 16: a bright, sunlit scene meters at EV 15.
    /// f/16 at 1/128 s, ISO 100 is exactly 2^15 = 32768 → EV 15.
    @Test func sunny16MetersAtEV15() {
        let ev = ExposureEngine.evAtISO100(iso: 100, exposureDuration: 1.0 / 128.0, aperture: 16)
        #expect(abs(ev - 15) < 0.001)
    }

    /// The zero of the EV scale: f/1.0 at 1 s, ISO 100.
    @Test func unitExposureIsEV0() {
        let ev = ExposureEngine.evAtISO100(iso: 100, exposureDuration: 1.0, aperture: 1)
        #expect(abs(ev - 0) < 0.001)
    }

    /// Normalizing to ISO 100: doubling the ISO the camera chose means the scene
    /// is one stop dimmer, so EV@ISO100 drops by 1.
    @Test func doublingISODropsEVByOneStop() {
        let base = ExposureEngine.evAtISO100(iso: 100, exposureDuration: 1.0 / 128.0, aperture: 16)
        let doubled = ExposureEngine.evAtISO100(iso: 200, exposureDuration: 1.0 / 128.0, aperture: 16)
        #expect(abs((base - doubled) - 1) < 0.001)
    }

    /// A valid reading converts through the failable overload to the same EV as
    /// the primitive form (Sunny 16 → EV 15).
    @Test func validReadingConvertsToEV() {
        let ev = ExposureEngine.evAtISO100(
            for: LightReading(iso: 100, exposureDuration: 1.0 / 128.0, aperture: 16)
        )
        #expect(ev != nil)
        #expect(abs((ev ?? .nan) - 15) < 0.001)
    }

    /// Physically impossible readings (non-positive or non-finite legs) are
    /// rejected so NaN/±infinity can never reach the meter's EV state.
    @Test(arguments: [
        LightReading(iso: 0, exposureDuration: 1.0 / 128.0, aperture: 16),
        LightReading(iso: -100, exposureDuration: 1.0 / 128.0, aperture: 16),
        LightReading(iso: 100, exposureDuration: 0, aperture: 16),
        LightReading(iso: 100, exposureDuration: -0.5, aperture: 16),
        LightReading(iso: 100, exposureDuration: 1.0 / 128.0, aperture: 0),
        LightReading(iso: .nan, exposureDuration: 1.0 / 128.0, aperture: 16),
        LightReading(iso: 100, exposureDuration: .infinity, aperture: 16),
        LightReading(iso: 100, exposureDuration: 1.0 / 128.0, aperture: .nan),
    ])
    func rejectsPhysicallyInvalidReadings(_ reading: LightReading) {
        #expect(ExposureEngine.evAtISO100(for: reading) == nil)
    }

    /// Pins the aperture term: halving N² (f/16 → f/11.3) halves N²/t, so the
    /// computed EV drops by exactly one stop.
    @Test func apertureTermFollowsLog2OfNSquared() {
        let f16 = ExposureEngine.evAtISO100(iso: 100, exposureDuration: 1.0 / 128.0, aperture: 16)
        // N such that N² is half of 16²: N = 16 / sqrt(2) ≈ 11.3137
        let fWide = ExposureEngine.evAtISO100(iso: 100, exposureDuration: 1.0 / 128.0, aperture: 16 / 2.0.squareRoot())
        #expect(abs((f16 - fWide) - 1) < 0.001)
    }

    // MARK: - Aperture-priority solve (t = N² / (2^EV100 · ISO/100))

    /// Sunny 16 inverted: EV 15 at ISO 100, f/16 solves to the reference
    /// exposure 1/128 s (which snaps to the dial mark 1/125).
    @Test func aperturePrioritySolvesSunny16Shutter() {
        let raw = ExposureEngine.shutterDuration(evAtISO100: 15, iso: 100, aperture: 16)
        #expect(abs(raw - 1.0 / 128) < 1e-9)
    }

    /// Doubling ISO is one stop more sensitive, so the balancing shutter is one
    /// stop faster (half the duration).
    @Test func doublingISOHalvesTheSolvedShutter() {
        let base = ExposureEngine.shutterDuration(evAtISO100: 15, iso: 100, aperture: 16)
        let faster = ExposureEngine.shutterDuration(evAtISO100: 15, iso: 200, aperture: 16)
        #expect(abs(base / faster - 2) < 1e-9)
    }

    /// Opening up two stops (f/16 → f/8, one quarter the N²) lets in four times
    /// the light, so the balancing shutter is four times faster (one quarter the
    /// duration).
    @Test func openingApertureShortensTheSolvedShutter() {
        let narrow = ExposureEngine.shutterDuration(evAtISO100: 15, iso: 100, aperture: 16)
        let wide = ExposureEngine.shutterDuration(evAtISO100: 15, iso: 100, aperture: 8)
        #expect(abs(narrow / wide - 4) < 1e-9)
    }

    /// A dimmer scene solves to a slower (longer) shutter — the demo behavior:
    /// the solved shutter tracks the light down.
    @Test func dimmerSceneSolvesToSlowerShutter() {
        let bright = ExposureEngine.shutterDuration(evAtISO100: 15, iso: 100, aperture: 8)
        let dim = ExposureEngine.shutterDuration(evAtISO100: 10, iso: 100, aperture: 8)
        #expect(dim > bright)
    }

    // MARK: - solvedTriangle (snapped, solved-leg flagged)

    @Test func solvedTriangleFlagsShutterAndSnapsAllLegs() {
        let triangle = ExposureEngine.solvedTriangle(evAtISO100: 15, iso: 100, aperture: 16)

        #expect(triangle.solved == .shutter)
        #expect(triangle.isSolved(.shutter))
        #expect(!triangle.isSolved(.aperture))
        #expect(!triangle.isSolved(.iso))

        #expect(triangle.iso.label == "100")
        #expect(triangle.aperture.label == "16")
        // 1/128 s solves and snaps to the dial mark 1/125.
        #expect(triangle.shutter?.label == "1/125")
    }

    /// Off-scale ISO/aperture inputs are snapped to real stops before solving.
    @Test func solvedTriangleSnapsOffScaleInputs() {
        let triangle = ExposureEngine.solvedTriangle(evAtISO100: 15, iso: 430, aperture: 15.5)
        #expect(triangle.iso.label == "400")
        #expect(triangle.aperture.label == "16")
    }
}
