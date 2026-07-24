import SwiftUI

/// The permanent slot for the graduated ruler: the instrument face of the
/// portrait dial panel, and the row folded under the chips in landscape's drawer.
///
/// The dial is always bound — to the priority leg by default, to whichever
/// editable leg the photographer taps, or transiently to EV compensation — so it
/// is visible and usable the moment the screen appears and never shows an empty
/// state. A shared meter control: it carries the `.dial` tour anchor so
/// guided-tour targeting survives orientation changes.
struct MeterDialHost: View {
    let model: MeterViewModel

    var body: some View {
        LinearDialView(
            labels: model.dialLabels,
            graduations: model.dialGraduations,
            selectedIndex: model.dialStopIndex,
            caption: model.dialCaption,
            onSelect: { model.setDialStopIndex($0) }
        )
        .guidedTourAnchor(.dial)
    }
}
