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

    /// Pins the aperture term: halving N² (f/16 → f/11.3) halves N²/t, so the
    /// computed EV drops by exactly one stop.
    @Test func apertureTermFollowsLog2OfNSquared() {
        let f16 = ExposureEngine.evAtISO100(iso: 100, exposureDuration: 1.0 / 128.0, aperture: 16)
        // N such that N² is half of 16²: N = 16 / sqrt(2) ≈ 11.3137
        let fWide = ExposureEngine.evAtISO100(iso: 100, exposureDuration: 1.0 / 128.0, aperture: 16 / 2.0.squareRoot())
        #expect(abs((f16 - fWide) - 1) < 0.001)
    }
}
