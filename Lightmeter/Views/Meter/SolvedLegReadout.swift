import Foundation

// MARK: - SolvedLegReadout (what the hero says)
//
// The meter's headline used to be EV@ISO100 — a property of the scene that the
// photographer still has to convert into a camera setting in their head. The
// hero is now the *answer* instead: the leg the engine solved, captioned for
// whichever leg that is. Aperture-priority solves the shutter, so the hero reads
// "Shutter @ ISO 100 / 1/125"; claiming the shutter flips the solve, and the
// hero becomes "Aperture @ ISO 100 / f/16".
//
// Pure over `ExposureTriangle`, so it's tested without a view — the same shape
// as `ExposureChipsView.role(...)`.

/// The hero readout's content, derived from the solved leg of an exposure
/// triangle.
///
/// The leg's *units* are carried by the value's own dial marking rather than a
/// separate suffix, exactly as a camera marks them and as the chips already do:
/// a solved shutter reads `1/125` (or `2"` when slow), a solved aperture reads
/// `f/16`. So changing which leg is solved changes the units by construction,
/// and there is no redundant "SEC" to contradict a `2"` marking.
struct SolvedLegReadout: Equatable {
    /// Names the leg the hero is answering for, and the ISO it is the answer at
    /// — e.g. `"Shutter @ ISO 100"`. Cased for display by the view.
    let caption: String

    /// The solved leg's snapped dial marking, or `nil` while the solve is
    /// pending (before the first reading), which the view shows as a
    /// placeholder rather than a stale value.
    let value: String?

    /// What VoiceOver reads in place of the caption — the same words, since the
    /// caption already names the leg and the ISO it answers at.
    var accessibilityLabel: String { caption }

    /// What VoiceOver reads in place of the value. The view shows an em-dash
    /// while the solve is pending; spoken, a dash is meaningless (and some voices
    /// say nothing at all), so the pending state is said in words.
    var accessibilityValue: String { value ?? "Pending" }
}

extension SolvedLegReadout {
    /// Derives the hero from `triangle`'s solved leg.
    init(triangle: ExposureTriangle) {
        caption = "\(triangle.solved.caption) @ ISO \(triangle.iso.label)"
        value = triangle.marking(of: triangle.solved)
    }
}
