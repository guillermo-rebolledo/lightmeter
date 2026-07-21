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

    // MARK: - Shutter-priority solve (N = √(t · 2^EV100 · ISO/100))

    /// Sunny 16 inverted the other way: EV 15 at ISO 100, 1/128 s solves to the
    /// reference aperture f/16.
    @Test func shutterPrioritySolvesSunny16Aperture() {
        let raw = ExposureEngine.apertureFNumber(evAtISO100: 15, iso: 100, shutter: 1.0 / 128)
        #expect(abs(raw - 16) < 1e-9)
    }

    /// Doubling ISO is one stop more sensitive, so the balancing aperture stops
    /// down one stop — N grows by √2.
    @Test func doublingISOOpensTheSolvedApertureBySqrt2() {
        let base = ExposureEngine.apertureFNumber(evAtISO100: 15, iso: 100, shutter: 1.0 / 128)
        let stopped = ExposureEngine.apertureFNumber(evAtISO100: 15, iso: 200, shutter: 1.0 / 128)
        #expect(abs(stopped / base - 2.0.squareRoot()) < 1e-9)
    }

    /// A slower (longer) shutter lets in more light, so the balancing aperture
    /// stops down: four times the duration is two stops, N doubles.
    @Test func slowerShutterStopsDownTheSolvedAperture() {
        let fast = ExposureEngine.apertureFNumber(evAtISO100: 15, iso: 100, shutter: 1.0 / 128)
        let slow = ExposureEngine.apertureFNumber(evAtISO100: 15, iso: 100, shutter: 1.0 / 32)
        #expect(abs(slow / fast - 2) < 1e-9)
    }

    /// A dimmer scene solves to a wider (smaller-N) aperture — the shutter-priority
    /// demo behavior: the solved aperture opens up as the light drops.
    @Test func dimmerSceneSolvesToWiderAperture() {
        let bright = ExposureEngine.apertureFNumber(evAtISO100: 15, iso: 100, shutter: 1.0 / 128)
        let dim = ExposureEngine.apertureFNumber(evAtISO100: 10, iso: 100, shutter: 1.0 / 128)
        #expect(dim < bright)
    }

    /// The two solves are inverses: an aperture-priority solve for the shutter,
    /// fed back as the shutter input, recovers the original aperture.
    @Test func apertureAndShutterSolvesAreInverses() {
        let ev = 12.0, iso = 200.0, aperture = 5.6
        let t = ExposureEngine.shutterDuration(evAtISO100: ev, iso: iso, aperture: aperture)
        let n = ExposureEngine.apertureFNumber(evAtISO100: ev, iso: iso, shutter: t)
        #expect(abs(n - aperture) < 1e-9)
    }

    // MARK: - solvedTriangle (snapped, solved-leg flagged)

    @Test func aperturePriorityTriangleFlagsShutterAndSnapsAllLegs() {
        let triangle = ExposureEngine.solvedTriangle(
            mode: .aperturePriority, evAtISO100: 15, iso: 100, aperture: 16, shutter: 1.0 / 125
        )

        #expect(triangle.solved == .shutter)
        #expect(triangle.isSolved(.shutter))
        #expect(!triangle.isSolved(.aperture))
        #expect(!triangle.isSolved(.iso))

        #expect(triangle.iso.label == "100")
        #expect(triangle.aperture?.label == "16")
        // 1/128 s solves and snaps to the dial mark 1/125.
        #expect(triangle.shutter?.label == "1/125")
    }

    /// Shutter-priority flips it: the aperture is now the solved (flagged) leg,
    /// the shutter is the locked input, and the aperture snaps to a real stop.
    @Test func shutterPriorityTriangleFlagsApertureAndSnapsAllLegs() {
        let triangle = ExposureEngine.solvedTriangle(
            mode: .shutterPriority, evAtISO100: 15, iso: 100, aperture: 16, shutter: 1.0 / 128
        )

        #expect(triangle.solved == .aperture)
        #expect(triangle.isSolved(.aperture))
        #expect(!triangle.isSolved(.shutter))
        #expect(!triangle.isSolved(.iso))

        #expect(triangle.iso.label == "100")
        // 1/128 s snaps to the dial mark 1/125; the aperture solves to f/16.
        #expect(triangle.shutter?.label == "1/125")
        #expect(triangle.aperture?.label == "16")
    }

    /// Before metering, the solved leg is pending (`nil`) while the locked legs
    /// are set — in each mode the opposite leg is the pending one.
    @Test func solvedTriangleLeavesTheSolvedLegPendingBeforeMetering() {
        let av = ExposureEngine.solvedTriangle(
            mode: .aperturePriority, evAtISO100: nil, iso: 100, aperture: 16, shutter: 1.0 / 125
        )
        #expect(av.aperture?.label == "16")
        #expect(av.shutter == nil)

        let tv = ExposureEngine.solvedTriangle(
            mode: .shutterPriority, evAtISO100: nil, iso: 100, aperture: 16, shutter: 1.0 / 125
        )
        #expect(tv.shutter?.label == "1/125")
        #expect(tv.aperture == nil)
    }

    /// Off-scale ISO/aperture inputs are snapped to real stops before solving.
    @Test func solvedTriangleSnapsOffScaleInputs() {
        let triangle = ExposureEngine.solvedTriangle(
            mode: .aperturePriority, evAtISO100: 15, iso: 430, aperture: 15.5, shutter: 1.0 / 125
        )
        #expect(triangle.iso.label == "400")
        #expect(triangle.aperture?.label == "16")
    }

    // MARK: - EV compensation

    /// Positive compensation deliberately overexposes: at fixed ISO and
    /// aperture, +1 EV doubles the solved exposure duration by one stop.
    @Test func positiveCompensationShiftsTheSolveTowardOverexposure() {
        let triangle = ExposureEngine.solvedTriangle(
            mode: .aperturePriority,
            evAtISO100: 15,
            compensation: 1,
            iso: 100,
            aperture: 16,
            shutter: 1.0 / 125
        )

        #expect(triangle.shutter?.label == "1/60")
    }

    /// Negative compensation deliberately underexposes: at fixed ISO and
    /// aperture, −1 EV halves the solved exposure duration by one stop.
    @Test func negativeCompensationShiftsTheSolveTowardUnderexposure() {
        let triangle = ExposureEngine.solvedTriangle(
            mode: .aperturePriority,
            evAtISO100: 15,
            compensation: -1,
            iso: 100,
            aperture: 16,
            shutter: 1.0 / 125
        )

        #expect(triangle.shutter?.label == "1/250")
    }

    /// Compensation is additive in stop-space: two successive nudges have the
    /// same target EV as their sum.
    @Test func compensationIsAdditive() {
        let afterFirst = ExposureEngine.targetEV(evAtISO100: 15, compensation: 2.0 / 3)
        let afterSecond = ExposureEngine.targetEV(evAtISO100: afterFirst, compensation: 1.0 / 3)
        let combined = ExposureEngine.targetEV(evAtISO100: 15, compensation: 1)

        #expect(abs(afterSecond - combined) < 1e-12)
    }

    // MARK: - Advisories

    @Test func shutterAdvisoriesRespectThresholdEdges() {
        let atHandheldLimit = ExposureEngine.advisories(
            mode: .aperturePriority,
            evAtISO100: log2(60),
            iso: 100,
            aperture: 1,
            shutter: 1.0 / 125
        )
        let roundOffAboveHandheldLimit = ExposureEngine.advisories(
            mode: .aperturePriority,
            evAtISO100: log2(1 / ((1.0 / 60) * (1 + 5e-13))),
            iso: 100,
            aperture: 1,
            shutter: 1.0 / 125
        )
        let slowerThanHandheldLimit = ExposureEngine.advisories(
            mode: .aperturePriority,
            evAtISO100: log2(50),
            iso: 100,
            aperture: 1,
            shutter: 1.0 / 125
        )
        let atTripodThreshold = ExposureEngine.advisories(
            mode: .aperturePriority,
            evAtISO100: log2(15),
            iso: 100,
            aperture: 1,
            shutter: 1.0 / 125
        )

        #expect(atHandheldLimit.isEmpty)
        #expect(roundOffAboveHandheldLimit.isEmpty)
        #expect(slowerThanHandheldLimit == [.handheldRisk])
        #expect(atTripodThreshold == [.tripodRecommended])
    }

    @Test func shutterOutsideScaleIsReportedBeforeSnapping() {
        let advisories = ExposureEngine.advisories(
            mode: .aperturePriority,
            evAtISO100: 0,
            iso: 100,
            aperture: 8,
            shutter: 1.0 / 125
        )

        #expect(advisories.contains(.tripodRecommended))
        #expect(advisories.contains(.outsideTypicalRange(.shutter)))
    }

    @Test func apertureOutsideScaleIsReportedBeforeSnapping() {
        let advisories = ExposureEngine.advisories(
            mode: .shutterPriority,
            evAtISO100: 20,
            iso: 100,
            aperture: 8,
            shutter: 1
        )

        #expect(advisories == [.outsideTypicalRange(.aperture)])
    }

    @Test func rangeAdvisoriesRespectScaleEdges() {
        let fastestShutter = ExposureEngine.advisories(
            mode: .aperturePriority,
            evAtISO100: log2(8000),
            iso: 100,
            aperture: 1,
            shutter: 1.0 / 125
        )
        let fasterThanScale = ExposureEngine.advisories(
            mode: .aperturePriority,
            evAtISO100: log2(9000),
            iso: 100,
            aperture: 1,
            shutter: 1.0 / 125
        )
        let slowestShutter = ExposureEngine.advisories(
            mode: .aperturePriority,
            evAtISO100: log2(1.0 / 30),
            iso: 100,
            aperture: 1,
            shutter: 1.0 / 125
        )
        let widestAperture = ExposureEngine.advisories(
            mode: .shutterPriority,
            evAtISO100: 0,
            iso: 100,
            aperture: 8,
            shutter: 1
        )
        let widerThanScale = ExposureEngine.advisories(
            mode: .shutterPriority,
            evAtISO100: -1,
            iso: 100,
            aperture: 8,
            shutter: 1
        )
        let narrowestAperture = ExposureEngine.advisories(
            mode: .shutterPriority,
            evAtISO100: 10,
            iso: 100,
            aperture: 8,
            shutter: 1
        )

        #expect(fastestShutter.isEmpty)
        #expect(fasterThanScale == [.outsideTypicalRange(.shutter)])
        #expect(slowestShutter == [.tripodRecommended])
        #expect(widestAperture.isEmpty)
        #expect(widerThanScale == [.outsideTypicalRange(.aperture)])
        #expect(narrowestAperture.isEmpty)
    }

    @Test func pendingSolveHasNoAdvisories() {
        let advisories = ExposureEngine.advisories(
            mode: .aperturePriority,
            evAtISO100: nil,
            iso: 100,
            aperture: 8,
            shutter: 1.0 / 125
        )

        #expect(advisories.isEmpty)
    }
}
