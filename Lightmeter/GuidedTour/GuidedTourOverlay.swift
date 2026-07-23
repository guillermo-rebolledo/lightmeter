import SwiftUI

struct GuidedTourOverlay: View {
    let step: GuidedTourStep
    /// The spotlight target in full-screen coordinates, or `nil` for steps with
    /// no anchor (the welcome step), which render a centered intro card instead.
    let targetFrame: CGRect?
    let progressLabel: String
    let onAdvance: () -> Void
    let onSkip: () -> Void

    /// Shared scrim opacity so the spotlight cutout and the anchorless centered
    /// card dim the screen by the same amount.
    private static let scrimOpacity = 0.72

    var body: some View {
        ZStack {
            if let targetFrame {
                spotlight(targetFrame: targetFrame)
            } else {
                centeredCard
            }

            VStack {
                HStack {
                    Text(progressLabel)
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.white)
                        .allowsHitTesting(false)

                    Spacer()

                    Button("Skip", action: onSkip)
                        .font(.body.bold())
                        .foregroundStyle(.yellow)
                        .frame(minWidth: 44, minHeight: 44)
                }
                Spacer()
            }
            .padding()
        }
    }

    @ViewBuilder
    private func spotlight(targetFrame: CGRect) -> some View {
        let padding = step == .settings
            ? CGSize(width: 6, height: 6)
            : CGSize(width: 10, height: 8)
        let spotlightFrame = targetFrame.insetBy(dx: -padding.width, dy: -padding.height)
        let cornerRadius = step == .settings ? 12.0 : 16.0

        SpotlightShape(targetFrame: spotlightFrame, cornerRadius: cornerRadius)
            .fill(
                .black.opacity(Self.scrimOpacity),
                style: FillStyle(eoFill: true)
            )
            .ignoresSafeArea()

        Button("Continue tour", action: onAdvance)
            .buttonStyle(.plain)
            .labelStyle(.titleOnly)
            .foregroundStyle(.clear)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .accessibilityHidden(true)

        GuidedTourCalloutLayout(targetFrame: spotlightFrame) {
            GuidedTourCallout(step: step, onAdvance: onAdvance)
        }
    }

    @ViewBuilder
    private var centeredCard: some View {
        Color.black.opacity(Self.scrimOpacity)
            .ignoresSafeArea()

        GuidedTourCallout(step: step, onAdvance: onAdvance)
            .frame(maxWidth: 340)
            .padding(24)
    }
}
