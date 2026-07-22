import SwiftUI

/// The priority-mode toggle stacked above the exposure-triangle chips.
///
/// A shared meter control: it carries the `.priorityAndChips` tour anchor so
/// guided-tour targeting survives orientation changes.
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
