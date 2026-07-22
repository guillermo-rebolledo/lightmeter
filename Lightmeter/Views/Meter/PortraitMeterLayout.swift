import SwiftUI

/// The portrait arrangement of the metering HUD, floated over the preview near
/// the bottom edge: the scene EV@ISO100 reference above the exposure-triangle
/// controls in a material card, with a permanent slot for the arc dial below.
///
/// Composes the shared meter controls into the portrait layout. Each control is
/// a standalone view carrying its own tour anchor, so a future landscape layout
/// can reuse the same instances without duplicating the view tree or re-wiring
/// the guided tour.
struct PortraitMeterLayout: View {
    let model: MeterViewModel
    /// The advisories snapshot to display — frozen while the tour runs.
    let advisories: [ExposureAdvisory]
    let isTourActive: Bool

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: 16) {
                EVReadoutView(ev: model.ev)
                FreezeCompensationRow(model: model)
                MeterAdvisories(advisories: advisories, isTourActive: isTourActive)
                MeteringPatternRow(model: model)
                PriorityAndChipsGroup(model: model)
            }
            .padding(20)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            .padding(.horizontal, 16)

            MeterDialHost(model: model)
                .padding(.top, 8)
        }
        .padding(.bottom, 44)
    }
}
