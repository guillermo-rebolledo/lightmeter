import SwiftUI

/// The metering HUD's content column, shared by both orientations: a demoted
/// freeze icon beside a smaller EV readout, a thin advisory line, the inline
/// expanding control strip (compensation, pattern, priority), the exposure-triangle
/// chips, and — folded in below them in *both* orientations now — the horizontal
/// ruler dial.
///
/// Composing the *same* column in portrait and landscape is what keeps the two
/// orientations at parity and lets tour anchors survive rotation: every anchor
/// (`.evReadout`, `.priorityAndChips`, the strip's `.compensation` /
/// `.meteringPattern`, and the dial's `.dial`) lives on a shared control here, so
/// rotating reflows the column without tearing down the camera or re-wiring the
/// guided tour.
///
/// This view is only the padded content. The docking chrome — the two-corner
/// `GlassCardBackground` surface that bleeds to the screen edge, the stretch frame,
/// and the `glassGroup()` wrapper — is applied by each layout via the shared
/// `docked(edge:)` helper, which the surface stretches differently per edge
/// (content-height at the bottom, full-height at the trailing edge).
struct MeterHUDCard: View {
    let model: MeterViewModel
    /// The advisories snapshot to display — frozen while the tour runs.
    let advisories: [ExposureAdvisory]
    let isTourActive: Bool
    /// The guided tour's current step, forwarded to the control strip so it can
    /// force-open the section the active step targets (and its anchor resolves).
    var tourStep: GuidedTourStep?

    var body: some View {
        VStack(spacing: 12) {
            // Freeze is demoted to a small icon floated on the trailing edge as
            // an overlay, so the readout centers across the full width with no
            // mirrored empty slot opening a gap across the row. The readout's
            // widest element is the fixed "EV @ ISO 100" caption (~100pt); centered
            // on even the narrowest iPhone card it clears the 44pt trailing icon by
            // a wide margin, so the overlay never collides with it.
            EVReadoutView(ev: model.ev, isCompact: true)
                .frame(maxWidth: .infinity)
                .overlay(alignment: .trailing) {
                    FreezeButton(
                        isFrozen: model.isFrozen,
                        // Mirror `toggleFreeze`'s own guard so the button stays
                        // enabled in every state the toggle accepts.
                        canFreeze: model.latestReading != nil || model.isFrozen,
                        isCompact: true,
                        onToggle: model.toggleFreeze
                    )
                }
            MeterAdvisories(advisories: advisories, isTourActive: isTourActive, isCompact: true)
            MeterControlStrip(model: model, tourStep: tourStep)
            ExposureChipsView(
                triangle: model.triangle,
                boundComponent: model.boundComponent,
                onSelect: { model.bindDial(to: $0) }
            )
            .guidedTourAnchor(.priorityAndChips)
            // The ruler dial is always horizontal now, folded under the chips in
            // both orientations; the separate vertical-dial slot landscape used to
            // mount on its trailing edge is gone.
            MeterDialHost(model: model)
        }
        .padding(14)
    }
}
