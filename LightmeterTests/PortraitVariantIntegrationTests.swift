import SwiftUI
import Testing
@testable import Lightmeter

/// The portrait variant assembled: the coherence pass that can only be run once
/// the hero, chips, padlock, pills, and reticle are all in the card together.
///
/// The per-slice suites each pin one control in isolation — a chip's footprint
/// across roles, a pill's across open states, the padlock's across freeze. What
/// none of them can see is the *assembled* card: flipping priority moves the
/// marking from one chip to another, re-captions the hero, and re-values two
/// chips at once, and any one of those could grow a row the photographer taps by
/// position. So the assertions here drive a real `MeterViewModel` and measure the
/// column the layout docks.
@MainActor
struct PortraitVariantIntegrationTests {
    /// The card's width on a narrow current iPhone, minus the drawer's padding —
    /// the tightest realistic proposal, where a row that grows has the least
    /// slack to absorb it.
    private static let cardWidth: CGFloat = 320

    /// A metering view-model with one sunny-16 reading already in hand, so the
    /// triangle is solved and every control is in its live state.
    private func meteringModel() async -> MeterViewModel {
        let source = FakeLightSource()
        let model = MeterViewModel(source: source)
        await model.start()
        source.emit(LightReading(iso: 100, exposureDuration: 1.0 / 128.0, aperture: 16))
        for _ in 0..<10_000 where model.ev == nil {
            await Task.yield()
        }
        #expect(model.ev != nil, "the fake source never produced a reading")
        return model
    }

    /// The size the assembled HUD content resolves to at a fixed width — what the
    /// drawer stretches to, and therefore what must not move.
    private func cardSize(_ model: MeterViewModel) -> CGSize {
        fittingSize(
            MeterHUDCard(model: model, advisories: model.advisories, isTourActive: false)
        )
    }

    /// The chips row on its own, so a shift can be attributed to the row itself
    /// rather than to anything stacked above it.
    private func chipsSize(_ model: MeterViewModel) -> CGSize {
        fittingSize(
            ExposureChipsView(
                triangle: model.triangle,
                boundComponent: model.boundComponent,
                onSelect: { _ in }
            )
        )
    }

    /// One chip's ideal size, for a value the live model actually produced.
    private func chipSize(
        component: ExposureComponent,
        value: String,
        role: ExposureChipsView.ChipRole,
        isBound: Bool = false
    ) -> CGSize {
        let chip = ExposureValueChip(
            value: value,
            role: role,
            isBound: isBound,
            component: component,
            onSelect: { _ in }
        )
        return UIHostingController(rootView: chip).view.intrinsicContentSize
    }

    private func fittingSize(_ view: some View) -> CGSize {
        let host = UIHostingController(rootView: view.frame(width: Self.cardWidth))
        host.view.setNeedsLayout()
        host.view.layoutIfNeeded()
        return host.sizeThatFits(in: CGSize(width: Self.cardWidth, height: .greatestFiniteMagnitude))
    }

    // MARK: - End-to-end no reflow

    /// Claiming a leg — the variant's one gesture — is a pure repaint: neither the
    /// chips row nor the card around it changes size when the padlock moves from
    /// the aperture to the shutter and the hero re-captions itself.
    @Test func claimingPriorityNeverResizesTheChipsOrTheCard() async {
        let model = await meteringModel()

        let chipsBefore = chipsSize(model)
        let cardBefore = cardSize(model)
        #expect(chipsBefore.height > 0 && cardBefore.height > 0)

        // Aperture-priority by default: tapping the solved shutter claims it.
        #expect(model.triangle.solved == .shutter)
        model.selectChip(.shutter)
        #expect(model.triangle.solved == .aperture)

        #expect(chipsSize(model) == chipsBefore)
        #expect(cardSize(model) == cardBefore)

        // …and back, so the row is stable in both directions rather than merely
        // settling at a new size and staying there.
        model.selectChip(.aperture)
        #expect(model.triangle.solved == .shutter)
        #expect(chipsSize(model) == chipsBefore)
        #expect(cardSize(model) == cardBefore)
    }

    /// The row's outer size can't see a chip that grew — `EqualWidthRow` divides
    /// the row into equal columns whatever the content, so it would absorb the
    /// growth and shuffle the columns underneath instead. So the inside of the row
    /// is measured too: for every value the live model actually puts on a chip, in
    /// either mode, that chip's footprint is the same whether it is the padlocked
    /// leg, the solved one, or plain.
    ///
    /// This is the defect the variant designs out — the old AUTO badge grew the
    /// chip it landed on — checked against real solved values rather than a
    /// hand-picked string.
    @Test func everyValueTheMeterProducesFitsTheSameChipInEveryRole() async {
        let model = await meteringModel()

        for claimed in [ExposureComponent.shutter, .aperture] {
            model.selectChip(claimed)

            for component in [ExposureComponent.iso, .aperture, .shutter] {
                let value = model.triangle.marking(of: component) ?? ExposureTriangle.pendingMarking
                let sizes = [ExposureChipsView.ChipRole.held, .solved, .plain].map {
                    chipSize(component: component, value: value, role: $0)
                }
                #expect(sizes.allSatisfy { $0 == sizes[0] }, "\(component) \(value): \(sizes)")
                #expect(sizes[0].width > 0 && sizes[0].height > 0)
            }
        }
    }

    /// Moving the dial to a leg is the other thing a chip tap can do. The
    /// selection ring is a stroke inside the chip's bounds, so binding any leg —
    /// including ISO, which is never the held one — leaves the row where it was.
    @Test func bindingTheDialToAnyLegNeverResizesTheRow() async {
        let model = await meteringModel()
        let baseline = chipsSize(model)

        for component in [ExposureComponent.iso, .aperture, .shutter] {
            model.selectChip(component)
            #expect(chipsSize(model) == baseline, "\(component)")
        }
    }

    /// Freezing swaps the padlock's glyph beside the hero. The hero is centred
    /// across the full card width with the padlock overlaid on its trailing edge,
    /// so a freeze must not move the readout under a thumb mid-tap.
    @Test func freezingNeverResizesTheCard() async {
        let model = await meteringModel()
        let baseline = cardSize(model)

        model.toggleFreeze()
        #expect(model.isFrozen)
        #expect(cardSize(model) == baseline)
    }

    // MARK: - VoiceOver, assembled

    /// Every control in the card speaks a label *and* the state its accent or
    /// glyph shows sighted users. Assembled rather than per-control: the point is
    /// that a VoiceOver user sweeping the card is never handed a silent element,
    /// whichever leg is held.
    @Test func everyControlInTheCardSpeaksItsStateInBothModes() async {
        let model = await meteringModel()

        for claimed in [ExposureComponent.shutter, .aperture] {
            model.selectChip(claimed)

            let hero = SolvedLegReadout(triangle: model.triangle)
            #expect(hero.accessibilityLabel.isEmpty == false)
            #expect(hero.accessibilityValue.isEmpty == false)

            for component in [ExposureComponent.iso, .aperture, .shutter] {
                let role = ExposureChipsView.role(for: component, triangle: model.triangle)
                let value = model.triangle.marking(of: component) ?? ExposureTriangle.pendingMarking
                #expect(role.accessibilityValue(value).isEmpty == false)
                #expect(role.accessibilityHint(isBound: model.boundComponent == component).isEmpty == false)
            }

            let lock = FreezeButton.LockState(isFrozen: model.isFrozen)
            #expect(lock.accessibilityLabel.isEmpty == false)
            #expect(lock.accessibilityValue.isEmpty == false)

            for pill in MeterStatusPills.Control.allCases {
                #expect(pill.accessibilityLabel.isEmpty == false)
                #expect(pill.value(in: model).isEmpty == false)
            }
        }
    }

    /// The hero and the held chip must not read as the same thing: the hero is
    /// the leg the app solved, the padlocked chip is the leg the photographer
    /// pinned. Spoken, they name different legs in both modes.
    @Test func theHeroAndTheHeldChipNameDifferentLegs() async {
        let model = await meteringModel()

        for claimed in [ExposureComponent.shutter, .aperture] {
            model.selectChip(claimed)

            let solved = model.triangle.solved
            let held: ExposureComponent = solved == .shutter ? .aperture : .shutter
            #expect(ExposureChipsView.role(for: held, triangle: model.triangle) == .held)
            #expect(SolvedLegReadout(triangle: model.triangle).accessibilityLabel
                .hasPrefix(solved.caption))
        }
    }

    /// EV has one home now — the headline bar — and it reads the same in both
    /// metering patterns, because it reports the scene rather than the point.
    ///
    /// This is what the reticle's silence buys: sighted users tell a spot read
    /// from a whole-frame one by the reticle's presence, and a VoiceOver user by
    /// the metering-pattern pill, rather than by two differently-named EV
    /// elements that used to be the only difference between the two.
    @Test func evReadsTheSceneInBothPatterns() async {
        let model = await meteringModel()

        model.setPattern(.spot)
        model.placeSpot(at: .frameCenter)
        let spot = EVHeadlineReadout(ev: model.ev, triangle: model.triangle)

        model.setPattern(.average)
        let average = EVHeadlineReadout(ev: model.ev, triangle: model.triangle)

        #expect(spot == average)
        #expect(spot.accessibilityValue.contains("ISO 100"))
    }

    // MARK: - Guided tour off

    /// The variant is judged cold: the tour never presents on this branch, even
    /// in the state that would otherwise trigger it (metering, a reading in hand,
    /// never seen before). Pinned against the steps `ContentView` actually hands
    /// the controller, so re-enabling the tour can't happen by accident.
    @Test func theGuidedTourNeverPresentsOnTheVariant() async throws {
        #expect(ContentView.guidedTourSteps.isEmpty)

        // A fresh, torn-down defaults suite, as the other suites do: a first-run
        // user is exactly the state that would present the tour, so it must not
        // be a leftover from an earlier run that makes this pass.
        let suiteName = "PortraitVariantIntegrationTests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let preferences = MeterPreferences(defaults: defaults)
        #expect(preferences.hasSeenGuidedTour == false)
        let controller = GuidedTourController(
            preferences: preferences,
            model: await meteringModel(),
            steps: ContentView.guidedTourSteps
        )

        controller.update(for: .metering, isMeterReady: true, isVoiceOverRunning: false)
        #expect(controller.isPresented == false)
        #expect(controller.currentStep == nil)

        // Even asked for explicitly, from Settings.
        controller.requestReplay(for: .metering, isMeterReady: true, isVoiceOverRunning: false)
        #expect(controller.isPresented == false)
    }
}
