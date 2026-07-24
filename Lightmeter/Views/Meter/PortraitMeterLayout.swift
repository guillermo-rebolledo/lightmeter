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
/// bar has read it since #96) and the exposure chips with it. That leaves an
/// **intermediate state**: priority mode was changed by tapping the AUTO chip,
/// and the row that carried it is gone until #99 lands the segmented row that
/// owns both mode decisions. Metering pattern and compensation still float as
/// status pills until the same two tickets rehouse them.
///
/// Landscape keeps its own arrangement entirely — the drawer, its chips, the
/// padlock inside it, and the gear floating in the corner — and inherits only the
/// restyled dial.
struct PortraitMeterLayout: View {
    let model: MeterViewModel
    /// The advisories snapshot to display — frozen while the tour runs.
    let advisories: [ExposureAdvisory]
    let isTourActive: Bool
    /// The guided tour's current step, or `nil` when the tour isn't running —
    /// forwarded to the status pills, whose editors hold two of its anchors.
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

            // The occasional controls, still floating over the preview but now
            // below the bar that took their corner. They keep their own surfaces:
            // they are over the scene, not on the panel.
            MeterStatusPills(model: model, tourStep: tourStep)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, Self.panelInset)
                .padding(.top, 8)

            Spacer()

            MeterDialPanel(
                model: model,
                advisories: advisories,
                isTourActive: isTourActive
            )
            .padding(.horizontal, Self.panelInset)
            // Held off the bottom safe area by the same inset it is held off the
            // sides by, so it floats clear of the home indicator rather than
            // bleeding behind it the way the drawer did.
            .padding(.bottom, Self.panelInset)
        }
    }
}
