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
}

extension SolvedLegReadout {
    /// Derives the hero from `triangle`'s solved leg.
    init(triangle: ExposureTriangle) {
        caption = "\(triangle.solved.caption) @ ISO \(triangle.iso.label)"
        value = Self.marking(of: triangle.solved, in: triangle)
    }

    /// A leg's value as a camera marks it: a bare number for ISO, an f-number
    /// for aperture, a duration for shutter. `nil` when the leg is pending.
    private static func marking(
        of component: ExposureComponent,
        in triangle: ExposureTriangle
    ) -> String? {
        switch component {
        // ISO is always a set input and never solved, but the mapping is kept
        // total so a future mode can't silently fall through to a placeholder.
        case .iso: triangle.iso.label
        case .aperture: triangle.aperture.map { "f/\($0.label)" }
        case .shutter: triangle.shutter?.label
        }
    }

    /// Shown in place of a pending value — the established em-dash placeholder.
    static let placeholder = "—"
}
