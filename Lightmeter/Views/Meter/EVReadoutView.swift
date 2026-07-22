import SwiftUI

/// The EV@ISO100 readout — the raw reference for the scene's light level.
///
/// A shared meter control: whichever layout composes it carries the
/// `.evReadout` tour anchor, so guided-tour targeting survives orientation
/// changes without the layout re-declaring the anchor.
struct EVReadoutView: View {
    let ev: Double?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 2) {
            Text("EV @ ISO 100")
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(1.5)

            Text(ev.map { String(format: "%.1f", $0) } ?? "—")
                .font(.system(size: 46, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white)
                .contentTransition(.numericText())
        }
        .animation(reduceMotion ? nil : .snappy, value: ev)
        .guidedTourAnchor(.evReadout)
    }
}
