import SwiftUI

/// The portrait arrangement of the metering HUD: the shared `MeterHUDCard`
/// hugging the bottom edge, with the ruler dial folded into the card below the
/// chips so the whole HUD reads as one small unit rather than several stacked
/// bands.
///
/// All content and chrome live in `MeterHUDCard`; this layout only positions it
/// — full-width against the bottom safe area. Landscape composes the same card
/// as a leading column, which is what keeps the two orientations at parity.
struct PortraitMeterLayout: View {
    let model: MeterViewModel
    /// The advisories snapshot to display — frozen while the tour runs.
    let advisories: [ExposureAdvisory]
    let isTourActive: Bool
    /// The guided tour's current step, forwarded to the shared card's control
    /// strip so it can force-open the section the active step targets.
    var tourStep: GuidedTourStep?

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            MeterHUDCard(
                model: model,
                advisories: advisories,
                isTourActive: isTourActive,
                tourStep: tourStep,
                foldsInDial: true
            )
            .padding(.horizontal, 16)
        }
        .padding(.bottom, 44)
    }
}
