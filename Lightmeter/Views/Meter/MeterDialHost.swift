import SwiftUI

/// The permanent slot for the arc dial.
///
/// The dial stays mounted so its gesture area is available before a target is
/// bound; only its visual content changes visibility. A shared meter control:
/// it carries the `.arcDial` tour anchor so guided-tour targeting survives
/// orientation changes.
struct MeterDialHost: View {
    let model: MeterViewModel
    /// The edge the dial hugs: horizontal (bottom) in portrait, vertical
    /// (trailing) in landscape. The same shared instance sweeps either axis.
    var axis: Axis = .horizontal

    var body: some View {
        ArcDialView(
            labels: model.dialLabels,
            selectedIndex: model.dialStopIndex,
            caption: model.dialCaption,
            axis: axis,
            onSelect: { model.setDialStopIndex($0) }
        )
        .guidedTourAnchor(.arcDial)
    }
}
