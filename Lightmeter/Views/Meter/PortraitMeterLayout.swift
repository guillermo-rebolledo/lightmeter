import SwiftUI

/// The portrait arrangement of the metering HUD: the shared `MeterHUDCard` content
/// docked as a **bottom drawer** — full-width, flush to the bottom edge, only its
/// top two corners rounded, with the ruler dial folded in below the chips so the
/// whole HUD reads as one unit rather than several stacked bands.
///
/// The drawer surface bleeds all the way to the physical bottom edge (behind the
/// home indicator); the content stays inside the safe area so it never collides
/// with it. Landscape docks the same content as a trailing drawer, which is what
/// keeps the two orientations at parity.
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
                tourStep: tourStep
            )
            // Full-width drawer flush to the bottom safe area; the two-corner
            // surface (glass on iOS 26, material + scrim on the floor) bleeds
            // down behind the home indicator, the content stays clear of it.
            .docked(edge: .bottom)
        }
    }
}
