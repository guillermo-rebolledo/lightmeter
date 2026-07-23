import SwiftUI

/// EV's average-metering home: a quiet secondary label over the preview.
///
/// Average metering reads the whole frame, so there is no point to pin a reticle
/// to — and drawing one would fool the photographer into thinking a single tone
/// was being measured. EV still matters, so it stays visible, just subordinate to
/// the hero (which now reads the solved exposure leg) and small enough to leave
/// the frame clear.
///
/// The spot counterpart is the reticle's inline badge, drawn by
/// `CameraPreviewView`; this view renders only the secondary-label case, so
/// handing it the readout in either pattern shows exactly one of the two.
struct PreviewEVReadoutView: View {
    /// The derived readout, or `nil` when EV has nothing to show.
    let readout: PreviewEVReadout?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if let readout, let value = readout.secondaryValue {
            Text(value)
                .font(.footnote.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(.white)
                .contentTransition(.numericText())
                .lineLimit(1)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                // The label floats on the raw scene — a blown-out sky washes out
                // white text — so it takes the same scrim the status pills use.
                .modifier(PreviewFloatingBackground())
                .animation(reduceMotion ? nil : .snappy, value: value)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(readout.accessibilityLabel)
                .accessibilityValue(readout.accessibilityValue)
        }
    }
}

#Preview {
    ZStack {
        // Stand in for a blown-out sky: the case the label's scrim exists for.
        LinearGradient(colors: [.white, .cyan], startPoint: .top, endPoint: .bottom)
            .ignoresSafeArea()
        VStack(spacing: 16) {
            // Average: the quiet label.
            PreviewEVReadoutView(
                readout: PreviewEVReadout(pattern: .average, spot: nil, ev: 12.34)
            )
            // Spot: EV rides the reticle instead, so this renders nothing.
            PreviewEVReadoutView(
                readout: PreviewEVReadout(pattern: .spot, spot: .frameCenter, ev: 12.34)
            )
        }
    }
    .tint(.appAccent)
    .preferredColorScheme(.dark)
}
