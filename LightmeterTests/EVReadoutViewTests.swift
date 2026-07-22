import Testing
@testable import Lightmeter

/// `EVReadoutView` gained an `isCompact` flag that shrinks the hero readout's
/// font (34pt vs. 46pt) for portrait's decluttered card. Font sizing isn't
/// observable without rendering, so these tests pin the stored configuration
/// and that `body` stays crash-free for the nil/formatted-value cases the
/// readout actually has to handle.
@MainActor
struct EVReadoutViewTests {
    // MARK: - isCompact defaulting

    @Test func isCompactDefaultsToFalseWhenOmitted() {
        let view = EVReadoutView(ev: 12.3)

        #expect(Mirror.storedValue("isCompact", on: view) == false)
    }

    @Test(arguments: [true, false])
    func isCompactStoresTheExplicitValue(_ isCompact: Bool) {
        let view = EVReadoutView(ev: 12.3, isCompact: isCompact)

        #expect(Mirror.storedValue("isCompact", on: view) == isCompact)
    }

    // MARK: - ev storage

    @Test func evValueIsStoredVerbatim() {
        let view = EVReadoutView(ev: 15.0)

        #expect(Mirror.storedValue("ev", on: view) == 15.0)
    }

    @Test func nilEVIsStoredAsNil() {
        let view = EVReadoutView(ev: nil)

        let stored: Double? = Mirror.storedValue("ev", on: view)
        #expect(stored == nil)
    }

    // MARK: - body stays crash-free

    @Test(arguments: [true, false])
    func bodyRendersTheDashPlaceholderWhenEVIsNil(_ isCompact: Bool) {
        let view = EVReadoutView(ev: nil, isCompact: isCompact)
        _ = view.body
    }

    @Test(arguments: [true, false])
    func bodyRendersAFormattedEVValue(_ isCompact: Bool) {
        let view = EVReadoutView(ev: -2.4, isCompact: isCompact)
        _ = view.body
    }
}