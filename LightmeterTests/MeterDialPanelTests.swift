import SwiftUI
import Testing
@testable import Lightmeter

/// The portrait dial panel as laid out: what it names and shows, and the height
/// that must not move under the thumb turning the rule inside it.
///
/// The panel floats at the bottom of the screen with the rule directly above its
/// footer, so its assertions are mostly *absence* assertions — nothing grows —
/// driven through a real `MeterViewModel` because the values and warnings that
/// would grow it are the ones the meter actually produces.
@MainActor
struct MeterDialPanelTests {
    /// The panel's width on a narrow current iPhone, minus its inset from both
    /// screen edges — the tightest realistic proposal, where a row that grows has
    /// the least slack.
    private static let panelWidth = 375 - 2 * PortraitMeterLayout.panelInset

    private func meteringModel(
        advisory: ExposureAdvisory? = nil
    ) async -> MeterViewModel {
        let source = FakeLightSource()
        let model = MeterViewModel(source: source)
        await model.start()
        // A one-second solve raises the tripod warning; a sunny-16 one raises
        // none. The caller picks which by asking for an advisory or not.
        let reading = advisory == nil
            ? LightReading(iso: 100, exposureDuration: 1.0 / 128.0, aperture: 16)
            : LightReading(iso: 100, exposureDuration: 1.0, aperture: 16)
        source.emit(reading)
        for _ in 0..<10_000 where model.ev == nil {
            await Task.yield()
        }
        #expect(model.ev != nil, "the fake source never produced a reading")
        return model
    }

    /// The size the panel resolves to at a fixed width — what a floating panel
    /// stretches to, and therefore what must not move.
    private func panelSize(_ model: MeterViewModel, advisories: [ExposureAdvisory]) -> CGSize {
        let host = UIHostingController(
            rootView: MeterDialPanel(model: model, advisories: advisories, isTourActive: false)
                .frame(width: Self.panelWidth)
        )
        host.view.setNeedsLayout()
        host.view.layoutIfNeeded()
        return host.sizeThatFits(
            in: CGSize(width: Self.panelWidth, height: .greatestFiniteMagnitude)
        )
    }

    // MARK: - What it names and shows

    /// The panel names whatever the dial is bound to and shows that leg's marking
    /// as its large numeral — the value under the needle, not the chip's `f/`
    /// form, so the headline and the mark it sits over are the same number.
    @Test func thePanelNamesAndShowsWhateverTheDialDrives() async {
        let model = await meteringModel()

        // Aperture-priority binds the dial to the aperture by default.
        #expect(model.dialCaption == ExposureComponent.aperture.caption)
        #expect(model.dialValue != nil)
        #expect(model.dialValue == model.dialLabels[model.dialStopIndex ?? -1])

        // Tapping ISO re-points it, and the panel's caption and value follow.
        model.selectChip(.iso)
        #expect(model.dialCaption == ExposureComponent.iso.caption)
        #expect(model.dialValue != nil)
        #expect(model.dialValue == model.dialLabels[model.dialStopIndex ?? -1])
    }

    /// The headline is the mark on the rule, not the chip's marking: an aperture
    /// reads `8`, never `f/8`, because the needle points at `8`.
    @Test func theHeadlineIsTheBareDialMarkNotTheChipMarking() async {
        let model = await meteringModel()
        model.selectChip(.aperture)

        let value = try? #require(model.dialValue)
        #expect(value?.hasPrefix("f/") == false)
        #expect(value == model.triangle.aperture?.label)
    }

    // MARK: - Nothing moves

    /// The panel's height is identical whether or not a warning is showing. The
    /// footer reserves its line unconditionally, so a tripod advisory arriving
    /// mid-drag cannot lift the rule out from under the thumb.
    @Test func theAdvisoryPresenceNeverResizesThePanel() async {
        let model = await meteringModel(advisory: .tripodRecommended)
        #expect(model.advisories.isEmpty == false)

        let withWarning = panelSize(model, advisories: model.advisories)
        let without = panelSize(model, advisories: [])
        #expect(withWarning.height > 0)
        #expect(withWarning == without)
    }

    /// …and identical across which leg the dial is bound to. ISO, aperture, and
    /// shutter have different scales and different widest markings; none of them
    /// may change the panel's height, so the instrument holds still as the
    /// photographer moves between them.
    @Test func bindingADifferentLegNeverResizesThePanel() async {
        let model = await meteringModel()
        let baseline = panelSize(model, advisories: [])

        for component in [ExposureComponent.iso, .aperture, .shutter] {
            model.selectChip(component)
            #expect(panelSize(model, advisories: []).height == baseline.height, "\(component)")
        }
    }

    /// …and identical as the value under the needle changes width. `1/8000` to
    /// `30"`, `f/1.4` to `f/32`: the numeral is one scale-to-fit line, so the
    /// panel around it holds.
    @Test func aValueThatChangesWidthNeverResizesThePanel() async {
        let model = await meteringModel()
        let baseline = panelSize(model, advisories: [])

        model.selectChip(.shutter)
        for shutter in [1.0 / 8000, 30.0] {
            model.setShutter(shutter)
            #expect(panelSize(model, advisories: []).height == baseline.height, "\(shutter)s")
        }
    }
}

/// The advisory footer in isolation: the reserved slot whose height is the same
/// whether or not a warning is in it, and grows with the text size.
///
/// The panel suite pins the *whole panel's* height across advisory presence; this
/// pins the footer that guarantees it, so a regression is attributed to the slot
/// rather than to something stacked above it.
@MainActor
struct MeterAdvisoryFooterTests {
    private func footerHeight(
        advisories: [ExposureAdvisory],
        size: DynamicTypeSize = .large
    ) -> CGFloat {
        let host = UIHostingController(
            rootView: MeterAdvisoryFooter(advisories: advisories, isTourActive: false)
                .dynamicTypeSize(size)
                .frame(width: 320)
        )
        host.view.setNeedsLayout()
        host.view.layoutIfNeeded()
        return host.sizeThatFits(in: CGSize(width: 320, height: CGFloat.greatestFiniteMagnitude)).height
    }

    /// Empty and filled resolve to the same height — the no-layout-shift
    /// requirement, and the easiest thing on this screen to silently regress.
    @Test func theSlotIsTheSameHeightEmptyOrFilled() {
        let empty = footerHeight(advisories: [])
        let filled = footerHeight(advisories: [.tripodRecommended])
        let twoWarnings = footerHeight(advisories: [.tripodRecommended, .outsideTypicalRange(.shutter)])

        #expect(empty > 0)
        #expect(filled == empty)
        // The compact line joins additional warnings inline rather than stacking,
        // so a second one does not grow the slot either.
        #expect(twoWarnings == empty)
    }

    /// …and the reserved height scales with Dynamic Type, so a user who set a
    /// larger text size gets a taller line rather than a clipped one.
    @Test func theSlotGrowsWithDynamicType() {
        let atLarge = footerHeight(advisories: [], size: .large)
        let atAccessibility = footerHeight(advisories: [], size: .accessibility3)
        #expect(atAccessibility > atLarge)

        // Filled tracks empty at the larger size too — the reservation is the same
        // shape as what fills it, so they scale together.
        #expect(footerHeight(advisories: [.tripodRecommended], size: .accessibility3) == atAccessibility)
    }

    /// Every advisory the engine can raise is worded, and the spoken line names
    /// each one — so shake, tripod, and out-of-range guidance reaches a VoiceOver
    /// user rather than being sighted-only.
    @Test func everyAdvisoryIsAnnounced() {
        let all: [ExposureAdvisory] = [
            .handheldRisk,
            .tripodRecommended,
            .outsideTypicalRange(.shutter),
            .outsideTypicalRange(.aperture),
        ]
        for advisory in all {
            #expect(advisory.message.isEmpty == false, "\(advisory)")
        }

        let spoken = AdvisoriesView.accessibilityLabel(for: [.tripodRecommended, .outsideTypicalRange(.shutter)])
        #expect(spoken.contains(ExposureAdvisory.tripodRecommended.message))
        #expect(spoken.contains(ExposureAdvisory.outsideTypicalRange(.shutter).message))
    }
}
