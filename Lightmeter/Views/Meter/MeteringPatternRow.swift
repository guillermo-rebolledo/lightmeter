import SwiftUI

/// The metering-pattern selector (Average / Spot).
///
/// The always-visible landscape presentation of the control, carrying the
/// `.meteringPattern` tour anchor. In portrait the same control lives inside
/// `PortraitControlStrip`, revealed on demand, where it re-declares that anchor.
struct MeteringPatternRow: View {
    let model: MeterViewModel

    var body: some View {
        MeteringPatternToggle(
            pattern: model.pattern,
            onSelect: { model.setPattern($0) }
        )
        .guidedTourAnchor(.meteringPattern)
    }
}
