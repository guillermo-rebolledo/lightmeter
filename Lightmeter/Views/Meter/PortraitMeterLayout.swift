import SwiftUI

/// The portrait arrangement of the metering HUD, as Direction 1b's instrument
/// face: the **EV headline bar** floating at the top of the screen, the status
/// pills under it, and today's HUD drawer still docked to the bottom edge.
///
/// The bar is the new hero — scene brightness as the screen's largest value, with
/// the freeze padlock and the settings gear rehoused at its two ends. It floats:
/// inset from the screen edges and anchored to the safe area, so the photographer
/// keeps a sense of the frame they are metering and the bar clears the Dynamic
/// Island without measuring it.
///
/// The drawer below is **unchanged** — the same shared `MeterHUDCard` content
/// landscape docks, minus the padlock that moved into the bar, full-width and
/// flush to the bottom edge with only its top two corners rounded. That makes
/// this an intermediate state (the solved leg is read in two places at once) but
/// a working one: everything the meter could do before this ticket, it still
/// does. The drawer is replaced by the dial panel in a later ticket.
///
/// Landscape keeps its own arrangement entirely — no bar, the padlock still in
/// the drawer, the gear still floating in the corner.
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

            MeterHUDCard(
                model: model,
                advisories: advisories,
                isTourActive: isTourActive,
                // The padlock lives at the leading end of the bar now.
                includesFreezeButton: false
            )
            // Full-width drawer flush to the bottom safe area; the two-corner
            // surface (glass, or material + scrim on the fallback) bleeds
            // down behind the home indicator, the content stays clear of it.
            .docked(edge: .bottom)
        }
    }
}
