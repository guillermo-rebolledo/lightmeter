import SwiftUI

struct GuidedTourOverlay: View {
    let step: GuidedTourStep
    let targetFrame: CGRect
    let progressLabel: String
    let onAdvance: () -> Void
    let onSkip: () -> Void

    var body: some View {
        let spotlightFrame = targetFrame.insetBy(dx: -10, dy: -8)

        ZStack {
            SpotlightShape(targetFrame: spotlightFrame, cornerRadius: 16)
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
