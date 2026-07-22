import Testing
@testable import Lightmeter

/// `MeterAdvisories` gained an `isCompact` flag that it forwards to the
/// underlying `AdvisoriesView` (portrait's single joined line vs. landscape's
/// stacked lines). These tests pin the stored configuration and that `body`
/// stays crash-free across the tour/compact/advisory combinations the meter
/// screen actually produces.
@MainActor
struct MeterAdvisoriesTests {
    // MARK: - isCompact defaulting

    @Test func isCompactDefaultsToFalseWhenOmitted() {
        let view = MeterAdvisories(advisories: [.handheldRisk], isTourActive: false)

        #expect(Mirror.storedValue("isCompact", on: view) == false)
    }

    @Test(arguments: [true, false])
    func isCompactStoresTheExplicitValue(_ isCompact: Bool) {
        let view = MeterAdvisories(advisories: [.handheldRisk], isTourActive: false, isCompact: isCompact)

        #expect(Mirror.storedValue("isCompact", on: view) == isCompact)
    }

    // MARK: - advisories / isTourActive storage

    @Test func advisoriesAndTourFlagAreStoredVerbatim() {
        let advisories: [ExposureAdvisory] = [.tripodRecommended, .outsideTypicalRange(.shutter)]
        let view = MeterAdvisories(advisories: advisories, isTourActive: true)

        #expect(Mirror.storedValue("advisories", on: view) == advisories)
        #expect(Mirror.storedValue("isTourActive", on: view) == true)
    }

    // MARK: - body stays crash-free

    @Test(arguments: [true, false])
    func bodyHidesAdvisoriesWhileTheTourIsActive(_ isCompact: Bool) {
        let view = MeterAdvisories(
            advisories: [.handheldRisk, .tripodRecommended],
            isTourActive: true,
            isCompact: isCompact
        )
        _ = view.body
    }

    @Test(arguments: [true, false])
    func bodyShowsAdvisoriesWhenTheTourIsInactive(_ isCompact: Bool) {
        let view = MeterAdvisories(
            advisories: [.outsideTypicalRange(.iso)],
            isTourActive: false,
            isCompact: isCompact
        )
        _ = view.body
    }

    @Test func bodyRendersWithNoAdvisoriesAtAll() {
        let view = MeterAdvisories(advisories: [], isTourActive: false, isCompact: true)
        _ = view.body
    }
}