import SwiftUI

struct GuidedTourOverlay: View {
    let step: GuidedTourStep
    let targetFrame: CGRect
    let progressLabel: String
    let onAdvance: () -> Void
    let onSkip: () -> Void

    var body: some View {
        let padding = step == .settings
            ? CGSize(width: 6, height: 6)
            : CGSize(width: 10, height: 8)
        let spotlightFrame = targetFrame.insetBy(dx: -padding.width, dy: -padding.height)
        let cornerRadius = step == .settings ? 12.0 : 16.0

        ZStack {
            SpotlightShape(targetFrame: spotlightFrame, cornerRadius: cornerRadius)
                .fill(
                    .black.opacity(0.72),
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
}
