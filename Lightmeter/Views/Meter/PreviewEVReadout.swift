import CoreGraphics
import Foundation

// MARK: - PreviewEVReadout (where EV lives now)
//
// EV lost the hero to the solved exposure leg — the setting the photographer
// actually dials in. It didn't lose its home: EV belongs at the *metered point*,
// so it moved into the preview layer.
//
// Spot metering already draws a reticle where the photographer tapped; EV rides
// it as an inline badge, so local brightness is read exactly where they're
// pointing. Average metering has no single point to point at — showing a reticle
// would fake one — so EV drops back to a quiet secondary label over the frame.
//
// Pure over already-published `pattern` / `spot` / `ev`, so it's tested without a
// view — the same shape as `SolvedLegReadout` and `ExposureChipsView.role(...)`.

/// What the preview layer shows for EV, and where.
struct PreviewEVReadout: Equatable {
    /// Where the EV reading is presented — the two are mutually exclusive, so a
    /// whole-frame read can never be dressed as a point measurement.
    enum Placement: Equatable {
        /// Spot metering: inline on the reticle, at the metered point.
        case reticleBadge
        /// Average metering: a quiet secondary label, with no reticle.
        case secondaryLabel
    }

    let placement: Placement

    /// The reading as shown — e.g. `"EV 12.3"`. Deliberately terse: the badge
    /// sits over the live scene, where a longer string would cover the frame.
    let value: String

    /// The value for the reticle badge, or `nil` when EV isn't badging a point —
    /// what `CameraPreviewView` renders on the reticle.
    var badgeValue: String? { placement == .reticleBadge ? value : nil }

    /// The value for the quiet secondary label, or `nil` when EV is on the
    /// reticle instead — what `PreviewEVReadoutView` renders.
    var secondaryValue: String? { placement == .secondaryLabel ? value : nil }

    /// Names which read this is: a spot reading and a whole-frame reading are
    /// different measurements, and sighted users tell them apart by the
    /// reticle's presence alone.
    var accessibilityLabel: String {
        switch placement {
        case .reticleBadge: "Spot exposure value"
        case .secondaryLabel: "Scene exposure value"
        }
    }

    /// Spoken, `"EV 12.3"` is a bare number, so the reference the glance-level
    /// readout leaves implicit is said aloud: EV is always at ISO 100.
    var accessibilityValue: String { "\(value) at ISO 100" }
}

extension PreviewEVReadout {
    /// Derives the readout from the published metering state, or `nil` when
    /// there is nothing to show: before the first reading, or while spot
    /// metering with no point placed (no reticle to badge).
    init?(pattern: MeteringPattern, spot: CGPoint?, ev: Double?) {
        guard let ev else { return nil }
        switch pattern {
        case .spot:
            guard spot != nil else { return nil }
            placement = .reticleBadge
        case .average:
            // The pattern alone decides: a spot left over from earlier spot
            // metering must not resurrect the badge on a whole-frame read.
            placement = .secondaryLabel
        }
        value = Self.label(ev)
    }

    /// One decimal, matching the precision of the EV@ISO100 readout this
    /// replaces.
    private static func label(_ ev: Double) -> String {
        "EV \(String(format: "%.1f", ev))"
    }
}
