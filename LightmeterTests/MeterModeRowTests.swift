import Testing
@testable import Lightmeter

/// The mode row's real logic: which cells each track offers, what every cell says
/// it is — including to VoiceOver, which can't see the small-caps glyph or the
/// accent tint — which cell is lit, and where a tap routes. Pure over the domain
/// enums and the row's own cell descriptors, so it's tested without a view, the
/// same shape as `MeterStatusPills.Control` and `ExposureChipsView.role(...)`.
///
/// The *behaviour* behind a tap — switching mode (and re-pointing the dial),
/// binding ISO, switching pattern — is `MeterViewModel`'s; the routing tests below
/// drive a real model to pin that the row hands the tap to the right entry point.
struct MeterModeRowTests {
    // MARK: - The two tracks are 3 + 2

    /// The left track is the three legs the single ruler can turn, in dial order.
    /// This is the row's one change of meaning: the left track was a priority pair
    /// and becomes a dial-target selector, now including ISO.
    @Test func theDialTargetTrackIsTheThreeDialableLegs() {
        #expect(MeterModeRow.dialTargets == [.aperture, .shutter, .iso])
    }

    /// The right track is average and spot — and *only* those. The handoff drew an
    /// incident segment; the app has no such pattern, so the type itself is what
    /// guarantees no incident segment can be shown.
    @Test func thePatternTrackIsAverageAndSpotWithNoIncident() {
        #expect(MeteringPattern.allCases == [.average, .spot])
    }

    // MARK: - Exactly one cell lit per track

    /// The left track's single highlight follows `boundComponent` — what the dial is
    /// turning — so exactly one cell is lit and it is the bound leg, whichever of the
    /// three that is.
    @Test func exactlyOneDialTargetCellIsLitAndItIsTheBoundLeg() {
        for bound in MeterModeRow.dialTargets {
            let lit = MeterModeRow.dialTargets.filter {
                MeterModeRow.dialTargetCell(for: $0, boundComponent: bound, isoMarking: "100")
                    .isSelected
            }
            #expect(lit == [bound], "\(bound)")
        }
    }

    /// While the ruler is on compensation, `boundComponent` is `nil` and the left
    /// track lights nothing — the comp readout carries the active state then, so two
    /// cells never light at once and no cell is stranded lit.
    @Test func noDialTargetCellIsLitWhileCompensationOwnsTheDial() {
        let lit = MeterModeRow.dialTargets.filter {
            MeterModeRow.dialTargetCell(for: $0, boundComponent: nil, isoMarking: "100")
                .isSelected
        }
        #expect(lit.isEmpty)
    }

    /// The right track lights exactly the active pattern — one highlight, unchanged
    /// by the row's restructure.
    @Test func exactlyOnePatternCellIsLit() {
        for selection in MeteringPattern.allCases {
            let lit = MeteringPattern.allCases.filter {
                MeterModeRow.patternCell(for: $0, selection: selection).isSelected
            }
            #expect(lit == [selection], "\(selection)")
        }
    }

    // MARK: - What the cells show

    /// The ISO cell is the only one that shows a value — `ISO 400` — because it is
    /// the only cell that doesn't flip priority, so its set-and-glance value would
    /// otherwise vanish when the dial is pointed elsewhere. Aperture and shutter
    /// name themselves and carry no value.
    @Test func onlyTheISOCellShowsItsLiveValue() {
        let iso = MeterModeRow.dialTargetCell(for: .iso, boundComponent: .aperture, isoMarking: "400")
        #expect(iso.title == "ISO 400")
        #expect(iso.accessibilityValue == "400")

        for component in [ExposureComponent.aperture, .shutter] {
            let cell = MeterModeRow.dialTargetCell(
                for: component, boundComponent: .aperture, isoMarking: "400"
            )
            #expect(cell.title == component.caption, "\(component)")
            #expect(cell.accessibilityValue == nil, "\(component)")
        }
    }

    // MARK: - VoiceOver

    /// Each cell names its role, so a dial-target cell and a pattern cell are
    /// distinguishable when read aloud rather than both sounding like the same kind
    /// of choice. Aperture and shutter speak as a *priority* (a tap holds that leg);
    /// ISO speaks its own name; the patterns name their metering axis.
    @Test func eachCellNamesItsRole() {
        #expect(MeterModeRow.dialTargetCell(for: .aperture, boundComponent: nil, isoMarking: "100")
            .accessibilityLabel == "Aperture priority")
        #expect(MeterModeRow.dialTargetCell(for: .shutter, boundComponent: nil, isoMarking: "100")
            .accessibilityLabel == "Shutter priority")
        #expect(MeterModeRow.dialTargetCell(for: .iso, boundComponent: nil, isoMarking: "100")
            .accessibilityLabel == "ISO")

        #expect(MeteringPattern.average.accessibilityLabel == "Average metering")
        #expect(MeteringPattern.spot.accessibilityLabel == "Spot metering")
    }

    /// The ISO cell carries a hint saying what its tap does — relocating ISO from
    /// the top bar must not cost the control the bar hint gave it. Aperture and
    /// shutter carry a hint too, since their tap does two things at once.
    @Test func theDialTargetCellsCarryHints() {
        let iso = MeterModeRow.dialTargetCell(for: .iso, boundComponent: nil, isoMarking: "100")
        #expect(iso.accessibilityHint?.isEmpty == false)
        #expect(iso.accessibilityHint?.lowercased().contains("dial") == true)

        for component in [ExposureComponent.aperture, .shutter] {
            let cell = MeterModeRow.dialTargetCell(for: component, boundComponent: nil, isoMarking: "100")
            #expect(cell.accessibilityHint?.isEmpty == false, "\(component)")
        }
    }

    /// No cell leaves a VoiceOver label — or its on-screen small-caps glyph — empty;
    /// both tracks are always fully labelled.
    @Test func noCellLeavesALabelEmpty() {
        for component in MeterModeRow.dialTargets {
            let cell = MeterModeRow.dialTargetCell(for: component, boundComponent: nil, isoMarking: "100")
            #expect(cell.accessibilityLabel.isEmpty == false, "\(component)")
            #expect(cell.title.isEmpty == false, "\(component)")
        }
        for pattern in MeteringPattern.allCases {
            let cell = MeterModeRow.patternCell(for: pattern, selection: .average)
            #expect(cell.accessibilityLabel.isEmpty == false, "\(pattern)")
            #expect(cell.title.isEmpty == false, "\(pattern)")
        }
    }
}

/// Where a tap on a dial-target cell routes, driven through a real `MeterViewModel`
/// because the whole point is that the row reaches the right already-existing entry
/// point. Aperture / shutter flip priority *and* aim the dial (`setMode`); ISO only
/// aims it (`selectChip`) — together, the dial drives the last thing you tapped.
@MainActor
struct MeterModeRowRoutingTests {
    private func model() -> MeterViewModel {
        MeterViewModel(source: FakeLightSource())
    }

    /// Tapping Aperture holds the aperture (aperture-priority) *and* points the dial
    /// at it — one gesture for what you hold and what you turn.
    @Test func tappingApertureHoldsItAndAimsTheDial() {
        let model = model()
        model.setMode(.shutterPriority)

        MeterModeRow.route(.aperture, on: model)

        #expect(model.mode == .aperturePriority)
        #expect(model.boundComponent == .aperture)
    }

    /// Tapping Shutter holds the shutter (shutter-priority) and points the dial at
    /// it, the mirror of aperture.
    @Test func tappingShutterHoldsItAndAimsTheDial() {
        let model = model()

        MeterModeRow.route(.shutter, on: model)

        #expect(model.mode == .shutterPriority)
        #expect(model.boundComponent == .shutter)
    }

    /// Tapping ISO aims the dial at the ISO scale *without* changing priority — so
    /// setting sensitivity never silently changes which leg you hold.
    @Test func tappingISOAimsTheDialWithoutChangingPriority() {
        let model = model()
        let priorityBefore = model.mode

        MeterModeRow.route(.iso, on: model)

        #expect(model.boundComponent == .iso)
        #expect(model.mode == priorityBefore)
    }

    /// Tapping any dial-target cell while the ruler is on compensation brings it
    /// home — the photographer is never stranded in comp.
    @Test func tappingADialTargetCellBringsTheRulerHomeFromCompensation() {
        for component in MeterModeRow.dialTargets {
            let model = model()
            model.bindCompensationDial()
            #expect(model.isCompensationDialBound, "\(component)")

            MeterModeRow.route(component, on: model)

            #expect(model.isCompensationDialBound == false, "\(component)")
            #expect(model.boundComponent != nil, "\(component)")
        }
    }
}
