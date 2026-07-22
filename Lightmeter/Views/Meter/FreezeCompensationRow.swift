import SwiftUI

/// The freeze toggle paired with the exposure-compensation control — the
/// landscape presentation, carrying the `.compensation` tour anchor on the
/// compensation control.
///
/// Portrait no longer uses this pairing: freeze is a standalone icon in the
/// persistent card and compensation moves into the on-demand
/// `PortraitControlStrip` (which re-declares the `.compensation` anchor there).
struct FreezeCompensationRow: View {
    let model: MeterViewModel

    var body: some View {
        HStack(spacing: 10) {
            FreezeButton(
                isFrozen: model.isFrozen,
                // Mirror `toggleFreeze`'s own guard so the button stays enabled
                // in every state the toggle accepts — including unfreezing —
                // and the two conditions can't drift apart in a later refactor.
                canFreeze: model.latestReading != nil || model.isFrozen,
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
