import SwiftUI

/// The portrait arrangement of the metering HUD: a single, light material card
/// hugging the bottom edge. The scene EV@ISO100 reference, the exposure-triangle
/// controls, and the ruler dial all fold into the *same* compact card, so the
/// whole HUD reads as one small unit rather than several stacked bands.
///
/// Composes the shared meter controls into the portrait layout. Each control is
/// a standalone view carrying its own tour anchor, so the landscape layout can
/// reuse the same instances without duplicating the view tree or re-wiring the
/// guided tour.
struct PortraitMeterLayout: View {
    let model: MeterViewModel
    /// The advisories snapshot to display — frozen while the tour runs.
    let advisories: [ExposureAdvisory]
    let isTourActive: Bool

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: 12) {
                EVReadoutView(ev: model.ev, isCompact: true)
                FreezeCompensationRow(model: model, isCompact: true)
                MeterAdvisories(advisories: advisories, isTourActive: isTourActive, isCompact: true)
                MeteringPatternRow(model: model)
                PriorityAndChipsGroup(model: model)
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
