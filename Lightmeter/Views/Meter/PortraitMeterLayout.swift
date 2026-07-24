import SwiftUI

/// The portrait arrangement of the metering HUD, as Direction 1b's instrument
/// face: two floating glass panels over the live scene, with the occasional
/// controls between them.
///
/// The **EV headline bar** at the top is the hero — scene brightness as the
/// screen's largest value, with the freeze padlock and the settings gear rehoused
/// at its two ends. The **dial panel** at the bottom is the instrument: the leg
/// the photographer is turning, over a graduated rule under a fixed needle, with
/// the advisory footer beneath it. Both float — inset from the screen edges and
/// anchored to the safe area — so the photographer keeps a sense of the frame
/// they are metering, the bar clears the Dynamic Island, and the panel clears the
/// home indicator, none of it measured by hand.
///
/// The panel replaces the docked HUD drawer, which took the solved-leg hero (the
/// bar has read it since #96) and the exposure chips with it. Below the panel, the
/// **mode row** carries the two mode decisions — priority (which leg you hold) and
/// metering pattern — as two independent segmented pairs (#99). It is what retires
/// the metering-pattern pill, and with it the whole portrait status-pill layer:
/// portrait no longer floats any pills, so this variant's only route to those
/// controls is the row.
///
/// Landscape keeps its own arrangement entirely — the drawer, its chips, the
/// padlock inside it, the status pills floating in the corner, and the gear — and
/// inherits only the restyled dial.
struct PortraitMeterLayout: View {
    let model: MeterViewModel
    /// The advisories snapshot to display — frozen while the tour runs.
    let advisories: [ExposureAdvisory]
    let isTourActive: Bool
    /// The guided tour's current step, or `nil` when the tour isn't running.
    /// Unused by the portrait layout now that its controls are the bar, the panel,
    /// and the mode row (none of which the disabled tour drives), but kept in the
    /// shared shape both layouts are constructed with.
    var tourStep: GuidedTourStep?

    /// The panels' inset from the screen edges — the handoff's 12pt margin, and
    /// what makes them read as floating over the scene rather than as chrome
    /// bolted to it.
    static let panelInset: CGFloat = 12

    var body: some View {
        VStack(spacing: 0) {
            EVHeadlineBar(model: model)
                .padding(.horizontal, Self.panelInset)
                .padding(.top, 8)

            Spacer()

            MeterDialPanel(
                model: model,
                advisories: advisories,
                isTourActive: isTourActive
            )
            .padding(.horizontal, Self.panelInset)

            // The two mode decisions — priority and metering pattern — as one quiet
            // row of small caps below the panel. It owns both mode controls now, so
            // portrait floats no status pills at all; the pattern pill and the whole
            // top-left pill layer are retired with it.
            MeterModeRow(model: model)
                .padding(.horizontal, Self.panelInset)
                .padding(.top, 8)
                // The row is the layout's bottom-most element, so it takes the same
                // inset off the bottom safe area the panel used to, floating clear
                // of the home indicator rather than bleeding behind it.
                .padding(.bottom, Self.panelInset)
        }
    }
}
