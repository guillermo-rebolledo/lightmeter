import Testing
@testable import Lightmeter

/// `PortraitMeterLayout` was restructured to fold the EV readout, the
/// freeze/compensation row, advisories, metering pattern, priority/chips, and
/// the ruler dial into a single card instead of stacking separate bands.
/// These tests pin the layout's own stored inputs and that `body` builds
/// without crashing across the meter states the portrait HUD actually shows.
@MainActor
struct PortraitMeterLayoutTests {
    // MARK: - stored inputs

    @Test func theProvidedModelInstanceIsStored() {
        let model = MeterViewModel(source: FakeLightSource())
        let layout = PortraitMeterLayout(model: model, advisories: [], isTourActive: false)

        let stored: MeterViewModel? = Mirror.storedValue("model", on: layout)
        #expect(stored === model)
    }

    @Test func advisoriesAndTourFlagAreStoredVerbatim() {
        let model = MeterViewModel(source: FakeLightSource())
        let advisories: [ExposureAdvisory] = [.handheldRisk, .tripodRecommended]
        let layout = PortraitMeterLayout(model: model, advisories: advisories, isTourActive: true)

        #expect(Mirror.storedValue("advisories", on: layout) == advisories)
        #expect(Mirror.storedValue("isTourActive", on: layout) == true)
    }

    // MARK: - body stays crash-free across meter states

    @Test func bodyRendersBeforeAnyReadingArrives() {
        let model = MeterViewModel(source: FakeLightSource())
        let layout = PortraitMeterLayout(model: model, advisories: [], isTourActive: false)
        _ = layout.body
    }

    @Test func bodyRendersWithAFrozenReadingAndAdvisories() async {
        let source = FakeLightSource()
        let model = MeterViewModel(source: source)
        await model.start()

        // A very dim scene at a fixed aperture solves to a slow shutter, which
        // surfaces a handheld-risk / tripod-recommended advisory — exercising
        // the same folded card the decluttered portrait layout composes.
        source.emit(LightReading(iso: 100, exposureDuration: 1.0, aperture: 1))
        for _ in 0..<10_000 where model.ev == nil {
            await Task.yield()
        }
        model.toggleFreeze()

        let layout = PortraitMeterLayout(model: model, advisories: model.advisories, isTourActive: false)
        _ = layout.body
    }

    @Test func bodyRendersWhileTheGuidedTourIsActive() {
        let model = MeterViewModel(source: FakeLightSource())
        let layout = PortraitMeterLayout(
            model: model,
            advisories: [.outsideTypicalRange(.aperture)],
            isTourActive: true
        )
        _ = layout.body
    }
}