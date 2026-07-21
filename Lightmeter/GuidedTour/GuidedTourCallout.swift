import SwiftUI

struct GuidedTourCallout: View {
    let step: GuidedTourStep

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(step.title)
                .font(.headline)

            Text(step.caption)
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
    }
}
