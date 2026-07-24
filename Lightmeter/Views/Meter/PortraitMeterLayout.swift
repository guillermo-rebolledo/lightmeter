import SwiftUI

/// The portrait arrangement of the metering HUD, as the **settings-first**
/// instrument face: the three values the photographer dials into their camera are
/// the hero, and scene EV is a quiet reference.
///
/// A photographer meters to answer "what do I set?" — ISO, shutter, aperture — not
/// to read a scene-brightness number no camera has an input for. So the
/// **exposure chips** are the headline: the full triangle as three large value
/// chips, with the AUTO (solved) leg marked, doubling as the priority control
/// (tap the AUTO leg to claim it). The **dial panel** below turns whichever leg
/// the photographer tapped, over a graduated rule under a fixed needle, with the
/// advisory footer beneath it. The **metering-pattern toggle** (average · spot)
/// sits at the very bottom.
///
/// Above them all, the **EV reference strip** is demoted from the old headline
/// bar: scene brightness as a small reference that still names its ISO-100
/// standard (ADR-0001), with the freeze padlock and the settings gear rehoused at
/// its two ends. Every element floats — inset from the screen edges and anchored
/// to the safe area — so the strip clears the Dynamic Island and the toggle clears
/// the home indicator, none of it measured by hand.
///
/// This reverses Direction 1b's EV-hero premise (#110); the chips, the padlock,
/// and the dial are the same tested components, re-cast so the loudest thing on
/// screen is the answer the photographer acts on. Landscape keeps its own
/// arrangement entirely — the drawer, its chips, the padlock inside it, the status
/// pills, and the gear — and inherits only the restyled dial.
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
            // Demoted EV: a quiet reference strip carrying the padlock and gear at
            // its ends, where the old headline bar was the hero.
            EVReferenceStrip(model: model)
                .padding(.horizontal, Self.panelInset)
                .padding(.top, 8)

            Spacer()

            // The hero: the exposure triangle as three large value chips. Tapping a
            // live leg aims the dial at it; tapping the AUTO leg claims priority —
            // the chips are the leg selector, so portrait needs no mode row.
            ExposureChipsView(
                triangle: model.triangle,
                boundComponent: model.boundComponent,
                emphasis: .hero,
                onSelect: model.selectChip
            )
            .padding(.horizontal, Self.panelInset)

            MeterDialPanel(
                model: model,
                advisories: advisories,
                isTourActive: isTourActive
            )
            .padding(.horizontal, Self.panelInset)
            .padding(.top, 8)

            // Metering pattern — the one mode decision the chips don't own — as a
            // quiet toggle below the panel, the layout's bottom-most element. It
            // takes the same inset off the bottom safe area, floating clear of the
            // home indicator rather than bleeding behind it.
            MeteringPatternToggle(pattern: model.pattern, onSelect: model.setPattern)
                .padding(.horizontal, Self.panelInset)
                .padding(.top, 8)
                .padding(.bottom, Self.panelInset)
        }
    }
}
