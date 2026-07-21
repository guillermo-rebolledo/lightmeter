import SwiftUI

/// Holds the current meter reading while settings are transferred to a camera.
struct FreezeButton: View {
    let isFrozen: Bool
    let canFreeze: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            Label(
                isFrozen ? "Resume" : "Hold",
                systemImage: isFrozen ? "play.fill" : "pause.fill"
            )
            .font(.footnote.bold())
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(
                isFrozen ? AnyShapeStyle(.tint.opacity(0.22)) : AnyShapeStyle(.white.opacity(0.08)),
                in: Capsule()
            )
            .overlay(
                Capsule()
                    .strokeBorder(.tint.opacity(isFrozen ? 0.8 : 0), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(canFreeze == false)
        .accessibilityLabel(isFrozen ? "Resume live metering" : "Hold current reading")
        .accessibilityHint(
            isFrozen
                ? "Accepts new light readings"
                : "Keeps the current exposure values steady"
        )
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        FreezeButton(isFrozen: true, canFreeze: true, onToggle: {})
            .padding()
    }
    .tint(.yellow)
    .preferredColorScheme(.dark)
}
