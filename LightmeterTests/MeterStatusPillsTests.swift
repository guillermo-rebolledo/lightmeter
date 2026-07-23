import SwiftUI
import Testing
@testable import Lightmeter

/// The top-left status pills' real logic: what each pill says it is and does —
/// including to VoiceOver, which can't see the glyph or the accent — and which
/// editor the guided tour would force open for a given step. Pure over the
/// control and its open state, so it's tested without a view, the same shape as
/// `ExposureChipsView.role(...)` and `FreezeButton.LockState`.
///
/// Pattern and compensation *behaviour* is `MeterViewModel`'s and is covered by
/// its own tests; the pills only relocate the controls.
struct MeterStatusPillsTests {
    // MARK: - VoiceOver

    /// Each pill names the control it adjusts, so the pair is distinguishable
    /// without seeing the two glyphs.
    @Test func eachPillNamesItsControl() {
        #expect(MeterStatusPills.Control.pattern.accessibilityLabel == "Metering pattern")
        #expect(MeterStatusPills.Control.compensation.accessibilityLabel == "Exposure compensation")
    }

    /// The pill's whole point is being readable at a glance; spoken, that state
    /// is the value — the current pattern, the current compensation.
    @MainActor
    @Test func eachPillSpeaksItsCurrentState() {
        let model = MeterViewModel(source: FakeLightSource())
        #expect(MeterStatusPills.Control.pattern.value(in: model) == model.pattern.label)
        #expect(MeterStatusPills.Control.compensation.value(in: model) == model.compensationLabel)
    }

    /// The hint says what the tap does, and it changes with the pill's state —
    /// a hint that read the same open and closed would mislead.
    @Test func eachPillHintsWhatTheTapWillDo() {
        for control in MeterStatusPills.Control.allCases {
            #expect(control.accessibilityHint(isOpen: false).isEmpty == false)
            #expect(control.accessibilityHint(isOpen: true) != control.accessibilityHint(isOpen: false))
        }
    }

    /// No pill leaves a VoiceOver slot empty.
    @Test func noPillLeavesAVoiceOverSlotEmpty() {
        for control in MeterStatusPills.Control.allCases {
            #expect(control.accessibilityLabel.isEmpty == false)
        }
    }

    // MARK: - Guided tour

    /// The tour force-opens the editor its step teaches, so the anchors that live
    /// inside the revealed controls resolve. Inherited from the control strip the
    /// pills replace: only placement changed.
    @Test func eachControlsStepOpensThatControlsEditor() {
        #expect(MeterStatusPills.tourEditor(for: .compensation) == .compensation)
        #expect(MeterStatusPills.tourEditor(for: .meteringPattern) == .pattern)
    }

    /// Steps whose control is elsewhere in the layout — and no tour at all —
    /// leave both editors collapsed.
    @Test func stepsElsewhereForceNothingOpen() {
        #expect(MeterStatusPills.tourEditor(for: .welcome) == nil)
        #expect(MeterStatusPills.tourEditor(for: .evReadout) == nil)
        #expect(MeterStatusPills.tourEditor(for: .priorityAndChips) == nil)
        #expect(MeterStatusPills.tourEditor(for: .dial) == nil)
        #expect(MeterStatusPills.tourEditor(for: .settings) == nil)
        #expect(MeterStatusPills.tourEditor(for: nil) == nil)
    }

    // MARK: - Footprint

    /// The pills sit over the preview and are tapped by position: opening a pill's
    /// editor must not resize the pill itself, or the pair would shuffle under the
    /// thumb that just tapped one.
    @MainActor
    @Test func openingAPillNeverChangesItsFootprint() {
        for control in MeterStatusPills.Control.allCases {
            let sizes = [false, true].map { idealPillSize(control: control, isOpen: $0) }
            #expect(sizes[0] == sizes[1], "\(control): \(sizes)")
            #expect(sizes[0].width > 0 && sizes[0].height > 0)
        }
    }

    /// Minimal, but still a real target: the pills clear the 44pt minimum height.
    @MainActor
    @Test func eachPillIsATappableTarget() {
        for control in MeterStatusPills.Control.allCases {
            #expect(idealPillSize(control: control, isOpen: false).height >= 44)
        }
    }

    @MainActor
    private func idealPillSize(control: MeterStatusPills.Control, isOpen: Bool) -> CGSize {
        let pill = MeterStatusPill(
            control: control,
            systemImage: "plusminus",
            value: "+0.0 EV",
            isOpen: isOpen,
            onTap: {}
        )
        return UIHostingController(rootView: pill).view.intrinsicContentSize
    }
}
