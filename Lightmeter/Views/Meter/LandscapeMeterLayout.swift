import SwiftUI

/// The landscape (`verticalSizeClass == .compact`) arrangement of the metering
/// HUD: the shared `MeterHUDCard` content docked as a **trailing drawer** —
/// full-height, flush to the right edge, width sized to content, only its two
/// leading (inner) corners rounded — with the preview hero showing through the
/// clear region on its leading side.
///
/// This collapses the old `[card column | vertical dial]` split into a single
/// drawer: the ruler dial is now a horizontal ruler folded into the content below
/// the chips (same as portrait), so the separate trailing-edge vertical-dial slot
/// is gone.
///
/// Composing the *same* `MeterHUDCard` content as `PortraitMeterLayout` — each
/// control carrying its own tour anchor — is what brings landscape to parity and
/// keeps rotation from tearing down the camera or re-wiring the guided tour.
/// Because the drawer sits on the trailing edge, the layout is identical for
/// `.landscapeLeft` and `.landscapeRight` (no per-rotation mirroring).
struct LandscapeMeterLayout: View {
    let model: MeterViewModel
    /// The advisories snapshot to display — frozen while the tour runs.
    let advisories: [ExposureAdvisory]
    let isTourActive: Bool
    /// The guided tour's current step, forwarded to the shared card's control
    /// strip so it can force-open the section the active step targets.
    var tourStep: GuidedTourStep?

    /// The trailing drawer's fixed content width, sized to hold the folded-in
    /// controls (and the horizontal ruler) comfortably without crowding the
    /// preview hero. Shared with `ContentView` so the settings gear can inset
    /// itself past the drawer.
    static let drawerWidth: CGFloat = 300

    var body: some View {
        HStack(spacing: 0) {
            // The preview hero shows through this leading region.
            Spacer(minLength: 0)

            // Scroll only when the content can't fit: `.basedOnSize` keeps it
            // pinned to the top at its natural height and starts scrolling only
            // when a short landscape height or large Dynamic Type sizes would
            // otherwise clip the chips or dial — and with them their tour anchors.
            ScrollView(.vertical) {
                MeterHUDCard(
                    model: model,
                    advisories: advisories,
                    isTourActive: isTourActive,
                    tourStep: tourStep
                )
                .frame(width: Self.drawerWidth)
            }
            .scrollBounceBehavior(.basedOnSize)
            .scrollIndicators(.hidden)
            .frame(width: Self.drawerWidth)
            // Full-height drawer: the content scrolls inside the safe area while
            // the two-corner surface fills the height and bleeds out past the
            // trailing / top / bottom safe areas to the physical edges.
            .docked(edge: .trailing)
        }
    }
}
