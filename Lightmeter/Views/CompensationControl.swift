import SwiftUI

/// The main-screen EV compensation readout and shared-dial binding control.
struct CompensationControl: View {
    let value: String
    let isBound: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 2) {
                Text("Compensation")
                    .font(.caption2.weight(.semibold))
                    .textCase(.uppercase)
                    .tracking(0.8)
                    .foregroundStyle(.secondary)

                Text(value)
                    .font(AppTypography.numeral(.footnote, weight: .bold))
                    .foregroundStyle(isBound ? AnyShapeStyle(.tint) : AnyShapeStyle(.white))
                    .contentTransition(.numericText())
                    // "+1.0 EV" in a monospaced face is wider than it was, and
                    // the capsule is the fixed-width half of a revealed editor.
                    .scaledToFitOnOneLine(minimumScale: 0.7)
            }
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(
                isBound ? AnyShapeStyle(.tint.opacity(0.22)) : AnyShapeStyle(.white.opacity(0.08)),
                in: Capsule()
            )
            .overlay(
                Capsule()
                    .strokeBorder(.tint.opacity(isBound ? 0.8 : 0), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("EV compensation")
        .accessibilityValue(value)
        .accessibilityAddTraits(isBound ? .isSelected : [])
        .accessibilityHint(isBound ? "Bound to dial" : "Bind to dial")
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        CompensationControl(value: "+1.0 EV", isBound: true, onSelect: {})
            .padding()
    }
    .tint(.appAccent)
    .preferredColorScheme(.dark)
}
