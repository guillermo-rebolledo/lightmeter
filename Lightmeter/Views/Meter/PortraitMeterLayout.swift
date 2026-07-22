import SwiftUI

/// The portrait arrangement of the metering HUD: a single, light material card
/// hugging the bottom edge. The scene EV@ISO100 reference, the exposure-triangle
/// chips, and the ruler dial all fold into the *same* compact card, so the whole
/// HUD reads as one small unit rather than several stacked bands.
///
/// The persistent set is exactly: the EV readout, the three chips, the folded-in
/// dial, a small freeze icon, and a thin advisory line. The occasional
/// controls — compensation, metering pattern, and priority mode — live in the
/// inline expanding `PortraitControlStrip` above the chips, revealed on demand
/// rather than always shown. (Landscape keeps them always-visible via its own
/// shared composite rows.)
struct PortraitMeterLayout: View {
    let model: MeterViewModel
    /// The advisories snapshot to display — frozen while the tour runs.
    let advisories: [ExposureAdvisory]
    let isTourActive: Bool
    /// The guided tour's current step, forwarded to the control strip so it can
    /// force-open the section the active step targets (and its anchor resolves).
    var tourStep: GuidedTourStep?

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: 12) {
                EVReadoutView(ev: model.ev, isCompact: true)
                    .frame(maxWidth: .infinity)
                    // Freeze is demoted to a small icon pinned to the card's
                    // top-trailing corner, clear of the centered readout.
                    .overlay(alignment: .topTrailing) {
                        FreezeButton(
                            isFrozen: model.isFrozen,
                            // Mirror `toggleFreeze`'s own guard so the button
                            // stays enabled in every state the toggle accepts.
                            canFreeze: model.latestReading != nil || model.isFrozen,
                            isCompact: true,
                            onToggle: model.toggleFreeze
                        )
                    }
                MeterAdvisories(advisories: advisories, isTourActive: isTourActive, isCompact: true)
                PortraitControlStrip(model: model, tourStep: tourStep)
                ExposureChipsView(
                    triangle: model.triangle,
                    boundComponent: model.boundComponent,
                    onSelect: { model.bindDial(to: $0) }
                )
                .guidedTourAnchor(.priorityAndChips)
                MeterDialHost(model: model)
            }
            .padding(14)
            // Material stays `.ultraThinMaterial`; the background layer alone is
            // dialed back so more of the preview shows through — the card reads
            // as more transparent without dimming the controls in front of it.
            .background {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .opacity(0.82)
            }
            .padding(.horizontal, 16)
        }
        .padding(.bottom, 44)
    }
}
