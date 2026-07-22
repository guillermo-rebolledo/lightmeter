import SwiftUI

/// The compact, thinner, more-transparent metering card shared by both
/// orientations: a demoted freeze icon beside a smaller EV readout, a thin
/// advisory line, the inline expanding control strip (compensation, pattern,
/// priority), and the exposure-triangle chips — all folded into one small
/// `.ultraThinMaterial` surface so the HUD reads as a single unit.
///
/// Composing the *same* card in portrait and landscape is what keeps the two
/// orientations at parity and lets tour anchors survive rotation: every anchor
/// (`.evReadout`, `.priorityAndChips`, and the strip's `.compensation` /
/// `.meteringPattern`) lives on a shared control here, so rotating reflows the
/// card without tearing down the camera or re-wiring the guided tour.
///
/// Portrait folds the ruler dial in below the chips (`foldsInDial: true`);
/// landscape runs the dial vertically along the trailing edge instead, mounting
/// its own `MeterDialHost` outside the card (`foldsInDial: false`). Positioning —
/// hugging the bottom in portrait, a fixed-width leading column in landscape —
/// stays with each layout; only the card's chrome and content live here.
struct MeterHUDCard: View {
    let model: MeterViewModel
    /// The advisories snapshot to display — frozen while the tour runs.
    let advisories: [ExposureAdvisory]
    let isTourActive: Bool
    /// The guided tour's current step, forwarded to the control strip so it can
    /// force-open the section the active step targets (and its anchor resolves).
    var tourStep: GuidedTourStep?
    /// Whether the ruler dial folds into the card below the chips (portrait) or
    /// is mounted separately on the trailing edge (landscape).
    let foldsInDial: Bool

    var body: some View {
        VStack(spacing: 12) {
            // Freeze is demoted to a small icon at the trailing edge; a matching
            // empty slot on the leading edge keeps the readout centered without
            // the icon ever overlapping it.
            HStack(spacing: 0) {
                Color.clear.frame(width: 44, height: 44)
                EVReadoutView(ev: model.ev, isCompact: true)
                    .frame(maxWidth: .infinity)
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
            if foldsInDial {
                MeterDialHost(model: model)
            }
        }
        .padding(14)
        // Liquid Glass on iOS 26, the dialed-back `.ultraThinMaterial` on the
        // iOS 17/18 floor (see `GlassCardBackground`). The card and every glass
        // control it holds — freeze, the strip buttons, the chips — share one
        // `GlassEffectContainer` via `glassGroup()` so adjacent glass blends as a
        // single system; on the fallback that grouping is a passthrough.
        .modifier(GlassCardBackground())
        .glassGroup()
    }
}
