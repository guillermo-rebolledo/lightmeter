import SwiftUI

/// The metering-pattern selector (Average / Spot).
///
/// A shared meter control: it carries the `.meteringPattern` tour anchor so
/// guided-tour targeting survives orientation changes without the composing
/// layout re-declaring the anchor.
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
