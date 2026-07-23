import Testing
@testable import Lightmeter

/// The hero readout's one piece of real logic: deriving the caption and value of
/// the *solved* leg from a triangle. Pure over `ExposureTriangle`, so — like
/// `ExposureChipsView.role(...)` — it's tested without a view.
struct SolvedLegReadoutTests {
    /// A solved triangle for a sunny-16 scene (EV 15) in `mode`.
    private func readout(
        mode: PriorityMode,
        evAtISO100: Double? = 15,
        iso: Double = 100,
        aperture: Double = 16,
        shutter: Double = 1.0 / 125
    ) -> SolvedLegReadout {
        SolvedLegReadout(
            triangle: ExposureEngine.solvedTriangle(
                mode: mode,
                evAtISO100: evAtISO100,
                iso: iso,
                aperture: aperture,
                shutter: shutter
            )
        )
    }

    /// Aperture-priority solves the shutter, so the hero answers "what shutter?"
    /// — captioned for the shutter leg and marked the way a shutter dial is.
    @Test func aperturePriorityHeroIsTheSolvedShutter() {
        let hero = readout(mode: .aperturePriority)

        #expect(hero.caption == "Shutter @ ISO 100")
        // Sunny 16 at ISO 100, f/16 → 1/125 s.
        #expect(hero.value == "1/125")
    }

    /// Shutter-priority flips which leg is solved, so both the caption and the
    /// value's unit notation flip with it: an f-number, not a duration.
    @Test func shutterPriorityHeroIsTheSolvedAperture() {
        let hero = readout(mode: .shutterPriority)

        #expect(hero.caption == "Aperture @ ISO 100")
        #expect(hero.value == "f/16")
    }

    /// The caption reports the photographer's actual ISO — the hero is only a
    /// dial-able answer if it says which ISO it is the answer *for*.
    @Test func captionCarriesTheSetISONotAFixedHundred() {
        #expect(readout(mode: .aperturePriority, iso: 400).caption == "Shutter @ ISO 400")
        #expect(readout(mode: .shutterPriority, iso: 800).caption == "Aperture @ ISO 800")
    }

    /// Before the first reading the solved leg is pending, so the hero has no
    /// value to show — the view renders the placeholder rather than a stale one.
    @Test func heroHasNoValueBeforeTheFirstReading() {
        #expect(readout(mode: .aperturePriority, evAtISO100: nil).value == nil)
        #expect(readout(mode: .shutterPriority, evAtISO100: nil).value == nil)

        // The caption still names the leg being solved, so the hero never reads
        // as blank while the meter warms up.
        #expect(readout(mode: .aperturePriority, evAtISO100: nil).caption == "Shutter @ ISO 100")
    }
}

/// The hero at the view-model seam: the readout tracks `triangle.solved` as the
/// photographer changes priority, driven by a fake source with no camera.
@MainActor
struct SolvedLegReadoutViewModelTests {
    /// Waits for `predicate` to hold, yielding to let the metering task run.
    private func waitUntil(
        _ predicate: () -> Bool,
        sourceLocation: SourceLocation = #_sourceLocation
    ) async {
        for _ in 0..<10_000 {
            if predicate() { return }
            await Task.yield()
        }
        Issue.record("Condition never became true", sourceLocation: sourceLocation)
    }

    /// Claiming a leg flips which leg the engine solves, and the hero follows:
    /// an aperture-priority shooter reads the required shutter, and the moment
    /// they claim the shutter the hero becomes the required aperture.
    @Test func heroFollowsThePriorityLegThePhotographerClaims() async {
        let source = FakeLightSource()
        let vm = MeterViewModel(source: source)
        await vm.start()

        // Sunny 16 → EV 15.
        source.emit(LightReading(iso: 100, exposureDuration: 1.0 / 128.0, aperture: 16))
        await waitUntil { vm.ev != nil }

        vm.setAperture(16)
        #expect(vm.triangle.solved == .shutter)
        #expect(SolvedLegReadout(triangle: vm.triangle) == SolvedLegReadout(
            caption: "Shutter @ ISO 100", value: "1/125"
        ))

        // Tap-to-claim the shutter chip: shutter becomes the held leg and the
        // hero switches to the aperture the app now solves.
        vm.selectChip(.shutter)
        #expect(vm.triangle.solved == .aperture)
        #expect(SolvedLegReadout(triangle: vm.triangle) == SolvedLegReadout(
            caption: "Aperture @ ISO 100", value: "f/16"
        ))
    }

    /// Before any reading arrives the solved leg is pending in both modes, so
    /// the hero shows no value — never a value left over from another mode.
    @Test func heroIsPendingUntilTheFirstReading() async {
        let source = FakeLightSource()
        let vm = MeterViewModel(source: source)
        await vm.start()

        #expect(SolvedLegReadout(triangle: vm.triangle).value == nil)

        vm.toggleMode()
        #expect(SolvedLegReadout(triangle: vm.triangle).value == nil)
    }
}
