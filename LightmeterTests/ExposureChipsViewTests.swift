import SwiftUI
import Testing
@testable import Lightmeter

/// The chips' one piece of real logic: mapping each leg to its role — held,
/// solved, or plain — the three-state visual language that makes the chips the
/// priority control in the portrait variant. Pure over `triangle`, so it's tested
/// without a view.
///
/// The variant flips which leg wears the marking: the padlock/accent now marks the
/// leg the photographer **holds**, not the one the app solves. The second half of
/// this suite pins the other half of that change — the marking rides in a reserved
/// constant slot, so a role change can never resize or shift a chip.
struct ExposureChipsViewTests {
    /// A solved aperture-priority triangle (EV 15, sunny 16): ISO and aperture are
    /// set, the shutter is solved.
    private func triangle(mode: PriorityMode) -> ExposureTriangle {
        ExposureEngine.solvedTriangle(
            mode: mode, evAtISO100: 15, iso: 100, aperture: 16, shutter: 1.0 / 125
        )
    }

    private func role(
        _ component: ExposureComponent,
        mode: PriorityMode
    ) -> ExposureChipsView.ChipRole {
        ExposureChipsView.role(for: component, triangle: triangle(mode: mode))
    }

    // MARK: - Role mapping

    /// Aperture-priority: the photographer holds the aperture (marked), the meter
    /// solves the shutter (muted), and ISO is plain.
    @Test func aperturePriorityMarksTheHeldAperture() {
        #expect(role(.aperture, mode: .aperturePriority) == .held)
        #expect(role(.shutter, mode: .aperturePriority) == .solved)
        #expect(role(.iso, mode: .aperturePriority) == .plain)
    }

    /// Shutter-priority flips it: the held shutter is marked, the aperture is the
    /// solved leg, ISO stays plain.
    @Test func shutterPriorityMarksTheHeldShutter() {
        #expect(role(.shutter, mode: .shutterPriority) == .held)
        #expect(role(.aperture, mode: .shutterPriority) == .solved)
        #expect(role(.iso, mode: .shutterPriority) == .plain)
    }

    /// ISO is never the marked leg. It is an input the photographer sets, but it is
    /// not the priority commitment the padlock reports, so it reads plain in both
    /// modes — and the dial can be bound to it without changing that.
    @Test func isoIsNeverMarked() {
        #expect(role(.iso, mode: .aperturePriority) == .plain)
        #expect(role(.iso, mode: .shutterPriority) == .plain)
    }

    /// Exactly one leg is held and exactly one is solved, in either mode: the
    /// marking is unambiguous at a glance.
    @Test func exactlyOneLegIsHeldAndOneIsSolved() {
        for mode in [PriorityMode.aperturePriority, .shutterPriority] {
            let roles = [ExposureComponent.iso, .aperture, .shutter].map { role($0, mode: mode) }
            #expect(roles.filter { $0 == .held }.count == 1)
            #expect(roles.filter { $0 == .solved }.count == 1)
            #expect(roles.filter { $0 == .plain }.count == 1)
        }
    }

    // MARK: - Marking glyph

    /// Only the held leg carries a glyph, and it's a *closed* padlock — the leg is
    /// pinned by the photographer.
    @Test func onlyTheHeldLegCarriesAClosedPadlock() {
        #expect(ExposureChipsView.ChipRole.held.markingSymbol == "lock.fill")
        #expect(ExposureChipsView.ChipRole.solved.markingSymbol == nil)
        #expect(ExposureChipsView.ChipRole.plain.markingSymbol == nil)
    }

    // MARK: - VoiceOver

    /// The padlock and the accent are both silent to VoiceOver, so the held state
    /// rides on the value — otherwise the variant's central cue (which leg am I
    /// holding?) would be sighted-only.
    @Test func onlyTheHeldChipSpeaksThatItIsHeld() {
        #expect(ExposureChipsView.ChipRole.held.spokenValue("f/16") == "f/16, held")
        #expect(ExposureChipsView.ChipRole.solved.spokenValue("1/125") == "1/125")
        #expect(ExposureChipsView.ChipRole.plain.spokenValue("100") == "100")
    }

    /// The solved chip is computed by the app but still interactive — tapping it
    /// hands the leg over — so it must read as claimable rather than as a
    /// read-only field, even when the dial happens to be bound to it.
    @Test func theSolvedChipHintsThatItCanBeClaimed() {
        for isBound in [false, true] {
            #expect(ExposureChipsView.ChipRole.solved.spokenHint(isBound: isBound)
                == "Auto — tap to control")
        }
    }

    /// The two legs the photographer owns hint at what the tap does instead: move
    /// the dial here, or report that it is already here.
    @Test func theOwnedChipsHintAtTheDialBinding() {
        for role in [ExposureChipsView.ChipRole.held, .plain] {
            #expect(role.spokenHint(isBound: false) == "Bind to dial")
            #expect(role.spokenHint(isBound: true) == "Bound to dial")
        }
    }

    /// No role leaves a VoiceOver slot empty, in either dial-binding state.
    @Test func noRoleLeavesAVoiceOverSlotEmpty() {
        for role in [ExposureChipsView.ChipRole.held, .solved, .plain] {
            #expect(role.spokenValue("f/16").isEmpty == false)
            #expect(role.spokenHint(isBound: false).isEmpty == false)
            #expect(role.spokenHint(isBound: true).isEmpty == false)
        }
    }

    // MARK: - Zero-reflow footprint

    /// The marking slot is reserved whether or not a glyph fills it, so the chip's
    /// ideal footprint is byte-identical across all three roles. This is the defect
    /// the variant designs out: the old AUTO badge grew the chip it landed on, so
    /// claiming priority reflowed the row under the photographer's thumb.
    @MainActor
    @Test func roleNeverChangesTheChipsFootprint() {
        let sizes = [ExposureChipsView.ChipRole.held, .solved, .plain].map { idealChipSize(role: $0) }
        #expect(sizes.allSatisfy { $0 == sizes[0] }, "\(sizes)")
        // Guard against the measurement silently collapsing to zero and making the
        // comparison above vacuous.
        #expect(sizes[0].width > 0 && sizes[0].height > 0)
    }

    /// The ring that marks the dial-bound leg is a stroke inside the chip's own
    /// bounds, so binding the dial doesn't move anything either.
    @MainActor
    @Test func bindingTheDialNeverChangesTheChipsFootprint() {
        #expect(idealChipSize(role: .held, isBound: true) == idealChipSize(role: .held, isBound: false))
    }

    /// The ideal (unproposed) size of a single chip — what the row's layout works
    /// from, and therefore the number that must not move when a role changes.
    @MainActor
    private func idealChipSize(
        role: ExposureChipsView.ChipRole,
        isBound: Bool = false
    ) -> CGSize {
        let chip = ExposureValueChip(
            value: "f/16",
            role: role,
            isBound: isBound,
            component: .aperture,
            onSelect: { _ in }
        )
        return UIHostingController(rootView: chip).view.intrinsicContentSize
    }
}
