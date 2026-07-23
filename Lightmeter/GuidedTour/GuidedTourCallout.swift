import SwiftUI

struct GuidedTourCallout: View {
    let step: GuidedTourStep
    let onAdvance: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                Text(step.title)
                    .font(.headline)

                Text(step.caption)
                    .font(.body)
                    .foregroundStyle(.secondary)

                Button(step.advanceButtonTitle, action: onAdvance)
                    .buttonStyle(.borderedProminent)
                    .tint(Color.appAccent)
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .padding()
        }
        .scrollBounceBehavior(.basedOnSize)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
    }
}
