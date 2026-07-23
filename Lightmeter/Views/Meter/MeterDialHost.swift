import SwiftUI

/// The permanent slot for the horizontal linear ruler dial, folded into the HUD
/// content below the chips in both orientations.
///
/// The dial stays mounted so its gesture area is available before a target is
/// bound; only its visual content changes visibility. A shared meter control:
/// it carries the `.dial` tour anchor so guided-tour targeting survives
/// orientation changes.
struct MeterDialHost: View {
    let model: MeterViewModel

    var body: some View {
        LinearDialView(
            labels: model.dialLabels,
            selectedIndex: model.dialStopIndex,
            caption: model.dialCaption,
            onSelect: { model.setDialStopIndex($0) }
        )
        .guidedTourAnchor(.dial)
    }
}
