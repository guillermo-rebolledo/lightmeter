import SwiftUI

/// **Landscape's** metering HUD content column: the freeze padlock beside the
/// solved-leg hero, a thin advisory line, the exposure-triangle chips, and the
/// graduated ruler folded in below them.
///
/// The occasional controls (metering pattern, compensation) are *not* here: they
/// float over the preview as `MeterStatusPills`, which is what clears the card
/// down to the readout, the chips, and the dial.
///
/// It was shared by both orientations until #97, where portrait's instrument face
/// replaced the docked drawer with the floating dial panel. Landscape's
/// arrangement is unchanged — 1b's composition is vertical and does not fit a
/// compact height, and there is no landscape mock — so it keeps this column, and
/// inherits the shared improvements the controls inside it carry (the accent, and
/// the restyled dial via `MeterDialHost`).
///
/// This view is only the padded content. The docking chrome — the two-corner
/// `GlassCardBackground` surface that bleeds to the screen edge, the stretch frame,
/// and the `glassGroup()` wrapper — is applied by the layout via the shared
/// `docked(edge:)` helper, which still knows both edges: the bottom drawer is what
/// this branch's portrait variant is being compared against, and it is where
/// portrait goes back to if the variant loses.
struct MeterHUDCard: View {
    let model: MeterViewModel
    /// The advisories snapshot to display — frozen while the tour runs.
    let advisories: [ExposureAdvisory]
    let isTourActive: Bool

    var body: some View {
        VStack(spacing: 12) {
            // The freeze padlock floats on the trailing edge as an overlay, so the
            // readout centers across the full width with no mirrored empty slot
            // opening a gap across the row. The readout's widest element is its
            // caption ("Shutter @ ISO 100", ~130pt); centered on even the narrowest
            // iPhone card it clears the 44pt trailing padlock by a comfortable
            // margin, so the overlay never collides with it.
            SolvedLegReadoutView(triangle: model.triangle)
                .frame(maxWidth: .infinity)
                .overlay(alignment: .trailing) {
                    FreezeButton(
                        isFrozen: model.isFrozen,
                        canFreeze: model.canFreeze,
                        onToggle: model.toggleFreeze
                    )
                }
                .id(GuidedTourStep.evReadout)
            MeterAdvisories(advisories: advisories, isTourActive: isTourActive, isCompact: true)
            ExposureChipsView(
                triangle: model.triangle,
                boundComponent: model.boundComponent,
                onSelect: { model.selectChip($0) }
            )
            .guidedTourAnchor(.priorityAndChips)
            .id(GuidedTourStep.priorityAndChips)
            // The ruler dial is always horizontal now, folded under the chips in
            // both orientations; the separate vertical-dial slot landscape used to
            // mount on its trailing edge is gone.
            MeterDialHost(model: model)
                .id(GuidedTourStep.dial)
        }
        .padding(14)
    }
}

extension MeterHUDCard {
    /// The scroll-target `id` for the row holding `step`'s tour anchor — the stable
    /// `.id(...)` values pinned on the rows above. When the landscape drawer is tall
    /// enough to scroll (short heights, large Dynamic Type), `LandscapeMeterLayout`
    /// scrolls to this id so the active guided-tour control is revealed rather than
    /// left off-screen under a stranded spotlight. `nil` for the steps whose control
    /// lives outside the drawer — the settings gear and, since they moved to the
    /// top-left status pills, metering pattern and compensation. Rows carry the same
    /// id in portrait, where there is no scroll container, so it is an inert view
    /// identity there.
    static func scrollTarget(for step: GuidedTourStep) -> GuidedTourStep? {
        switch step {
        case .welcome, .evReadout: .evReadout
        case .priorityAndChips: .priorityAndChips
        case .dial: .dial
        case .meteringPattern, .compensation, .settings: nil
        }
    }
}
