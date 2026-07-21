import SwiftUI

/// Safety guidance for the current exposure solve.
struct AdvisoriesView: View {
    let advisories: [ExposureAdvisory]

    var body: some View {
        if advisories.isEmpty == false {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(advisories, id: \.self) { advisory in
                    Label(advisory.message, systemImage: advisory.systemImage)
                        .font(.footnote.bold())
                        .foregroundStyle(.yellow)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityLabel("Exposure warning: \(advisory.message)")
                }
            }
        }
    }
}

private extension ExposureAdvisory {
    var message: String {
        switch self {
        case .handheldRisk:
            "Brace for camera shake"
        case .tripodRecommended:
            "Tripod recommended"
        case .outsideTypicalRange(let component):
            "\(component.caption) outside typical range"
        }
    }

    var systemImage: String {
        switch self {
        case .handheldRisk:
            "hand.raised.fill"
        case .tripodRecommended:
            "camera.fill"
        case .outsideTypicalRange:
            "exclamationmark.triangle.fill"
        }
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        AdvisoriesView(advisories: [
            .tripodRecommended,
            .outsideTypicalRange(.shutter),
        ])
        .padding()
    }
    .preferredColorScheme(.dark)
}
