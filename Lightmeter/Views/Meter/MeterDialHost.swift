import SwiftUI

/// The permanent slot for the horizontal linear ruler dial, folded into the HUD
/// content below the chips in both orientations.
///
/// The dial is always bound — to the priority leg by default, to whichever
/// editable leg the photographer taps, or transiently to EV compensation — so it
/// is visible and usable the moment the drawer opens and never shows an empty
/// state. A shared meter control: it carries the `.dial` tour anchor so
/// guided-tour targeting survives orientation changes.
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
