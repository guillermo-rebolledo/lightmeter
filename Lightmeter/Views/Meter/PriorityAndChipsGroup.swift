import SwiftUI

/// The priority-mode toggle stacked above the exposure-triangle chips — the
/// landscape presentation, carrying the `.priorityAndChips` tour anchor.
///
/// Portrait splits these apart: the chips stay in the persistent card (and carry
/// the anchor there), while priority moves into the on-demand
/// `PortraitControlStrip`.
struct PriorityAndChipsGroup: View {
    let model: MeterViewModel

    var body: some View {
        VStack(spacing: 16) {
            PriorityModeToggle(
                mode: model.mode,
                onSelect: { model.setMode($0) }
            )
            ExposureChipsView(
                triangle: model.triangle,
                boundComponent: model.boundComponent,
                onSelect: { model.bindDial(to: $0) }
            )
        }
        .guidedTourAnchor(.priorityAndChips)
    }
}
