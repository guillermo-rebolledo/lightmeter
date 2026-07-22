import Testing
@testable import Lightmeter

/// `AdvisoriesView` now renders in two shapes: the default stacked lines (one
/// advisory per line, for landscape) and a `isCompact` single joined line (for
/// portrait's decluttered card). These tests pin the stored configuration each
/// initializer produces and that `body` stays crash-free across the advisory
/// counts/orderings the meter can actually surface.
@MainActor
struct AdvisoriesViewTests {
    // MARK: - isCompact defaulting

    @Test func isCompactDefaultsToFalseWhenOmitted() {
        let view = AdvisoriesView(advisories: [.tripodRecommended])

        #expect(Mirror.storedValue("isCompact", on: view) == false)
    }

    @Test(arguments: [true, false])
    func isCompactStoresTheExplicitValue(_ isCompact: Bool) {
        let view = AdvisoriesView(advisories: [.handheldRisk], isCompact: isCompact)

        #expect(Mirror.storedValue("isCompact", on: view) == isCompact)
    }

    // MARK: - Advisories storage

    @Test func advisoriesArrayIsStoredVerbatim() {
        let advisories: [ExposureAdvisory] = [.handheldRisk, .tripodRecommended, .outsideTypicalRange(.iso)]
        let view = AdvisoriesView(advisories: advisories)

        #expect(Mirror.storedValue("advisories", on: view) == advisories)
    }

    @Test func emptyAdvisoriesArrayIsStoredAsEmpty() {
        let view = AdvisoriesView(advisories: [])

        let stored: [ExposureAdvisory]? = Mirror.storedValue("advisories", on: view)
        #expect(stored?.isEmpty == true)
    }

    // MARK: - body stays crash-free

    @Test func bodyRendersNothingWhenAdvisoriesAreEmpty() {
        let view = AdvisoriesView(advisories: [])
        _ = view.body
    }

    @Test func bodyRendersInStackedModeForEachAdvisoryCase() {
        let view = AdvisoriesView(
            advisories: [.handheldRisk, .tripodRecommended, .outsideTypicalRange(.shutter)],
            isCompact: false
        )
        _ = view.body
    }

    @Test func bodyRendersInCompactModeForEachAdvisoryCase() {
        let view = AdvisoriesView(
            advisories: [.handheldRisk, .tripodRecommended, .outsideTypicalRange(.aperture)],
            isCompact: true
        )
        _ = view.body
    }

    @Test func bodyRendersCompactSingleAdvisoryWithoutASeparator() {
        // A single advisory shouldn't need the " · " join at all — this just
        // pins that the single-element path doesn't crash on the joined text.
        let view = AdvisoriesView(advisories: [.tripodRecommended], isCompact: true)
        _ = view.body
    }
}