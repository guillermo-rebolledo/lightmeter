import SwiftUI

/// Safety guidance for the current exposure solve.
struct AdvisoriesView: View {
    let advisories: [ExposureAdvisory]
    /// Portrait's decluttered card collapses all advisories into one thin line;
    /// landscape keeps each advisory on its own labeled line (it has the room).
    var isCompact: Bool = false

    var body: some View {
        if let primary = advisories.first {
            if isCompact {
                compactLine(primary: primary)
            } else {
                stackedLines
            }
        }
    }

    /// What VoiceOver reads for a set of advisories.
    ///
    /// Pure and named, in the shape the readouts use, so "the warnings are
    /// announced" is a fact a test can pin rather than something that has to be
    /// read back off the accessibility tree. Spoken with commas rather than the
    /// interpuncts the line is drawn with: a middle dot is not a pause.
    static func accessibilityLabel(for advisories: [ExposureAdvisory]) -> String {
        "Exposure warnings: " + advisories.map(\.message).joined(separator: ", ")
    }

    /// The single thin line: the highest-priority advisory leads with its icon,
    /// and any remaining warnings are joined inline so the HUD stays one card.
    private func compactLine(primary: ExposureAdvisory) -> some View {
        Label {
            Text(advisories.map(\.message).joined(separator: " · "))
                .lineLimit(1)
        } icon: {
            Image(systemName: primary.systemImage)
        }
        .font(.caption)
        // The single accent token, not a second hardcoded colour: the advisory
        // line sits inside the same card as the hero, chips, and padlock, so a
        // stray literal here is exactly the drift the token exists to prevent.
        .foregroundStyle(Color.appAccent)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Self.accessibilityLabel(for: advisories))
    }

    /// Each advisory on its own full line, for layouts with vertical room.
    private var stackedLines: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(advisories, id: \.self) { advisory in
                Label(advisory.message, systemImage: advisory.systemImage)
                    .font(.footnote.bold())
                    .foregroundStyle(Color.appAccent)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityLabel("Exposure warning: \(advisory.message)")
            }
        }
    }
}

extension ExposureAdvisory {
    /// What the advisory says, drawn and spoken. Internal rather than private so
    /// the footer's wording is testable — an unworded warning is a warning that
    /// does not reach a VoiceOver user at all.
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

    /// The glyph that leads the line.
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
