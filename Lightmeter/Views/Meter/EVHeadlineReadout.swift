import Foundation

// MARK: - EVHeadlineReadout (what the instrument's headline says)
//
// Direction 1b inverts #76: scene brightness, not the solved leg, is the loudest
// thing on the screen. EV therefore leaves the metered point — where it was a
// reticle badge and a quiet secondary label — and becomes the headline of a
// floating bar pinned to the top of the meter.
//
// That promotion raises the cost of ADR-0001 from "a quiet number is ambiguous"
// to "the headline is wrong": EV read bare invites being taken as quoted at
// whatever sensitivity the meter is set to. So the reference is part of the
// caption here rather than a decoration a layout can drop.
//
// Pure over the already-published `ev` / `triangle`, so what the bar says is
// tested without a view — the same shape as `SolvedLegReadout`.

/// The EV headline bar's content: the scene's brightness and the leg the engine
/// solved. (ISO used to ride the bar too, but it has moved to the mode row with
/// the other legs the dial turns, so it is no longer part of the headline.)
struct EVHeadlineReadout: Equatable {
    /// Names the value below it *and the sensitivity it is quoted at* — e.g.
    /// `"Exposure value @ ISO 100"`. Cased for display by the view.
    ///
    /// The reference is fixed (ADR-0001), so this does not vary with the
    /// photographer's own ISO — which is the whole point of saying it beside a
    /// readout that does.
    let caption: String

    /// The scene reading as shown — e.g. `"EV 12.3"`, or `"EV —"` before the
    /// first reading rather than a stale or invented number.
    ///
    /// The whole string, kept intact so VoiceOver reads a single value; the bar
    /// typesets it as a small ``unit`` prefix over the large ``evValue`` number,
    /// which is presentation only and leaves this — and the accessibility value
    /// derived from it — unchanged. Composed from the pieces rather than stored, so
    /// the whole string and its parts can never drift.
    var value: String { "\(Self.unit) \(evValue)" }

    /// The unit prefix the bar draws small before the number — always `"EV"`.
    /// The bar splits the headline so `EV` reads as a quiet unit on the big
    /// figure rather than a same-size word held a digit away from it; the split
    /// is view typography, so the pieces live here but ``value`` stays whole.
    static let unit = "EV"

    /// The scene reading *without* its `EV` prefix — `"12.3"`, or the em-dash
    /// placeholder while pending — so the bar can render the number as its own
    /// large tabular run beside the small ``unit``.
    let evValue: String

    /// Names the leg the engine answered for — `"Shutter"` in aperture-priority,
    /// `"Aperture"` in shutter-priority. Spoken rather than drawn: sighted readers
    /// get the leg from the marking's own units.
    let solvedCaption: String

    /// The solved leg's snapped dial marking (`"1/125"`, `"f/16"`), or the app's
    /// em-dash placeholder while the solve is pending.
    let solvedValue: String

    /// Names which read this is. The bar reports the *scene*, not the metered
    /// point: since #96 the reticle carries no reading of its own.
    var accessibilityLabel: String { "Scene exposure value" }

    /// Spoken, `"EV 12.3"` is a bare number, so the reference the caption gives
    /// sighted readers is said aloud too (ADR-0001). The em-dash placeholder is
    /// meaningless read aloud, so pending is said in words.
    var accessibilityValue: String {
        isPending ? Self.pendingSpoken : "\(value) at ISO 100"
    }

    var solvedAccessibilityLabel: String { solvedCaption }

    /// Deferred to ``SolvedLegReadout`` — the drawer's hero reads the same leg a
    /// few inches below this one, and the two must not describe it differently.
    let solvedAccessibilityValue: String

    /// Whether the scene has yet been read.
    private let isPending: Bool

    private static let pendingSpoken = "Pending"
}

extension EVHeadlineReadout {
    /// Derives the bar from the scene's EV and the solved triangle.
    ///
    /// `ev` is `MeterViewModel.ev` — the calibrated EV@ISO 100 — and *not*
    /// anything derived from `triangle`'s legs. That separation is ADR-0001 made
    /// structural: there is no path by which changing ISO, aperture, shutter,
    /// priority, or compensation could reach this number.
    init(ev: Double?, triangle: ExposureTriangle) {
        caption = "Exposure value @ ISO \(Self.referenceISO)"
        isPending = ev == nil
        evValue = ev.map(Self.label) ?? ExposureTriangle.pendingMarking

        // The solved leg is derived by `SolvedLegReadout`, not re-derived here:
        // the drawer's hero renders the same leg a few inches below this one, and
        // two derivations of one value is how they start disagreeing about the
        // marking or about what "pending" is called. Only the caption differs —
        // the hero says "Shutter @ ISO 100" because it is the answer's headline,
        // and here the ISO 100 qualifier already belongs to the EV above.
        let solved = SolvedLegReadout(triangle: triangle)
        solvedCaption = triangle.solved.caption
        solvedValue = solved.value ?? ExposureTriangle.pendingMarking
        solvedAccessibilityValue = solved.accessibilityValue
    }

    /// The sensitivity EV is always quoted at (ADR-0001).
    private static let referenceISO = 100

    /// One decimal, the precision the meter has always reported EV at.
    private static func label(_ ev: Double) -> String {
        String(format: "%.1f", ev)
    }
}
