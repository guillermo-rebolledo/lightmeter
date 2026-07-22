import Testing
@testable import Lightmeter

/// `FreezeCompensationRow` gained an `isCompact` flag that it forwards to its
/// inner `FreezeButton` (icon-only in portrait's decluttered card). These
/// tests pin the row's own stored configuration and that `body` stays
/// crash-free across the view-model states the row actually observes.
@MainActor
struct FreezeCompensationRowTests {
    // MARK: - isCompact defaulting

    @Test func isCompactDefaultsToFalseWhenOmitted() {
        let model = MeterViewModel(source: FakeLightSource())
        let row = FreezeCompensationRow(model: model)

        #expect(Mirror.storedValue("isCompact", on: row) == false)
    }

    @Test(arguments: [true, false])
    func isCompactStoresTheExplicitValue(_ isCompact: Bool) {
        let model = MeterViewModel(source: FakeLightSource())
        let row = FreezeCompensationRow(model: model, isCompact: isCompact)

        #expect(Mirror.storedValue("isCompact", on: row) == isCompact)
    }

    // MARK: - model wiring

    @Test func theProvidedModelInstanceIsStored() {
        let model = MeterViewModel(source: FakeLightSource())
        let row = FreezeCompensationRow(model: model)

        let stored: MeterViewModel? = Mirror.storedValue("model", on: row)
        #expect(stored === model)
    }

    // MARK: - body stays crash-free

    @Test func bodyRendersBeforeAnyReadingWithFreezeDisabled() {
        let model = MeterViewModel(source: FakeLightSource())
        // No reading yet and not frozen — FreezeButton's canFreeze is false.
        let row = FreezeCompensationRow(model: model, isCompact: true)
        _ = row.body
    }

    @Test func bodyRendersOnceFrozenInBothLayoutModes() async {
        let source = FakeLightSource()
        let model = MeterViewModel(source: source)
        await model.start()
        source.emit(LightReading(iso: 100, exposureDuration: 1.0 / 128.0, aperture: 16))

        for _ in 0..<10_000 where model.ev == nil {
            await Task.yield()
        }
        model.toggleFreeze()

        _ = FreezeCompensationRow(model: model, isCompact: true).body
        _ = FreezeCompensationRow(model: model, isCompact: false).body
    }
}