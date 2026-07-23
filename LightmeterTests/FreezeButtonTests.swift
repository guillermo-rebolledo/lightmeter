import SwiftUI
import Testing
@testable import Lightmeter

/// The freeze control's one piece of real logic: what the padlock says about the
/// meter — open while it's live, closed while a reading is held — and the words
/// VoiceOver reads in place of the glyph. Pure over `isFrozen`, so it's tested
/// without a view, the same shape as `ExposureChipsView.role(...)`.
///
/// Freezing itself is `MeterViewModel`'s job and is covered by its own tests;
/// nothing here touches behaviour.
struct FreezeButtonTests {
    // MARK: - Padlock glyph

    /// The variant's whole point: the padlock is *open* while the meter is live
    /// and *closed* once a reading is held, so the photographer can tell at a
    /// glance whether the numbers are still moving.
    @Test func liveShowsAnOpenPadlockAndHeldAClosedOne() {
        #expect(FreezeButton.LockState.live.symbol == "lock.open.fill")
        #expect(FreezeButton.LockState.held.symbol == "lock.fill")
    }

    /// The closed padlock is the same glyph the held chip wears, so "closed
    /// padlock" means one thing across the whole variant.
    @Test func theClosedPadlockMatchesTheHeldChipsMarking() {
        #expect(FreezeButton.LockState.held.symbol == ExposureChipsView.ChipRole.held.markingSymbol)
    }

    /// `isFrozen` is the only input: frozen is held, everything else is live.
    @Test func lockStateFollowsIsFrozen() {
        #expect(FreezeButton.LockState(isFrozen: false) == .live)
        #expect(FreezeButton.LockState(isFrozen: true) == .held)
    }

    // MARK: - VoiceOver

    /// The padlock is silent to VoiceOver as a glyph, so both the action and the
    /// current state have to ride on the label and hint.
    @Test func eachStateNamesTheActionAndTheStateItIsIn() {
        #expect(FreezeButton.LockState.live.accessibilityLabel == "Hold current reading")
        #expect(FreezeButton.LockState.held.accessibilityLabel == "Resume live metering")

        for state in [FreezeButton.LockState.live, .held] {
            #expect(state.accessibilityHint.isEmpty == false)
        }
        #expect(FreezeButton.LockState.live.accessibilityHint != FreezeButton.LockState.held.accessibilityHint)
    }

    // MARK: - Zero-reflow footprint

    /// The padlock sits beside the hero, whose caption is centred across the
    /// card: if the button resized when the meter froze, the hero would shift
    /// under a thumb that is often mid-tap. Toggling freeze is a pure repaint.
    @MainActor
    @Test func freezingNeverChangesTheButtonsFootprint() {
        let sizes = [FreezeButton.LockState.live, .held].map { idealButtonSize(state: $0) }
        #expect(sizes.allSatisfy { $0 == sizes[0] }, "\(sizes)")
        // Guard against the measurement silently collapsing to zero and making
        // the comparison above vacuous.
        #expect(sizes[0].width > 0 && sizes[0].height > 0)
    }

    /// A circle, not a pill: the padlock's footprint is square, and at least the
    /// 44pt minimum tap target on both axes.
    @MainActor
    @Test func theButtonIsACircularTapTarget() {
        let size = idealButtonSize(state: .live)
        #expect(size.width == size.height)
        #expect(size.width >= 44)
    }

    /// Disabling the control (no reading to hold yet) doesn't move it either.
    @MainActor
    @Test func disablingNeverChangesTheButtonsFootprint() {
        #expect(idealButtonSize(state: .live, canFreeze: false) == idealButtonSize(state: .live))
    }

    @MainActor
    private func idealButtonSize(
        state: FreezeButton.LockState,
        canFreeze: Bool = true
    ) -> CGSize {
        let button = FreezeButton(
            isFrozen: state == .held,
            canFreeze: canFreeze,
            onToggle: {}
        )
        return UIHostingController(rootView: button).view.intrinsicContentSize
    }
}
