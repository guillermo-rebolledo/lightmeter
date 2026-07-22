import SwiftUI

/// The freeze toggle paired with the exposure-compensation control.
///
/// A shared meter control: it carries the `.compensation` tour anchor on the
/// compensation control so guided-tour targeting survives orientation changes.
struct FreezeCompensationRow: View {
    let model: MeterViewModel
    /// Portrait's decluttered card demotes freeze to a small icon button beside
    /// the compensation pill; landscape keeps both as full-width pills.
    var isCompact: Bool = false

    var body: some View {
        HStack(spacing: 10) {
            FreezeButton(
                isFrozen: model.isFrozen,
                // Mirror `toggleFreeze`'s own guard so the button stays enabled
                // in every state the toggle accepts — including unfreezing —
                // and the two conditions can't drift apart in a later refactor.
                canFreeze: model.latestReading != nil || model.isFrozen,
                isCompact: isCompact,
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
