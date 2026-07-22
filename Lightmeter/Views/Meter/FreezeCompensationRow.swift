import SwiftUI

/// The freeze toggle paired with the exposure-compensation control.
///
/// A shared meter control: it carries the `.compensation` tour anchor on the
/// compensation control so guided-tour targeting survives orientation changes.
struct FreezeCompensationRow: View {
    let model: MeterViewModel

    var body: some View {
        HStack(spacing: 10) {
            FreezeButton(
                isFrozen: model.isFrozen,
                canFreeze: model.latestReading != nil,
                onToggle: model.toggleFreeze
            )
            CompensationControl(
                value: model.compensationLabel,
                isBound: model.isCompensationDialBound,
                onSelect: model.bindCompensationDial
            )
            .guidedTourAnchor(.compensation)
        }
    }
}
