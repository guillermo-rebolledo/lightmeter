import SwiftUI

/// Holds the current meter reading while settings are transferred to a camera.
struct FreezeButton: View {
    let isFrozen: Bool
    let canFreeze: Bool
    /// Portrait's decluttered card demotes freeze to a small icon-only button;
    /// landscape keeps the full labeled pill that fills the row.
    var isCompact: Bool = false
    let onToggle: () -> Void

    private var systemImage: String { isFrozen ? "play.fill" : "pause.fill" }

    var body: some View {
        Button(action: onToggle) {
            label
                // `glassEffect` contributes no hit region, so pin the tappable
                // area to the full pill (matching the strip buttons and gear).
                .contentShape(Capsule())
                .modifier(GlassPillBackground(isActive: isFrozen))
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

    @ViewBuilder private var label: some View {
        if isCompact {
            Image(systemName: systemImage)
                .font(.footnote.bold())
                .frame(width: 44, height: 44)
        } else {
            Label(isFrozen ? "Resume" : "Hold", systemImage: systemImage)
                .font(.footnote.bold())
                .frame(maxWidth: .infinity, minHeight: 44)
        }
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        FreezeButton(isFrozen: true, canFreeze: true, onToggle: {})
            .padding()
    }
    .tint(.appAccent)
    .preferredColorScheme(.dark)
}
