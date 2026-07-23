import SwiftUI

/// The metering-pattern control: a two-segment glass pill that switches between a
/// center-weighted whole-frame average and a tap-placed spot. The selected segment
/// carries an accent-tinted highlight that slides between the two. Selecting the
/// already-active segment is a no-op.
struct MeteringPatternToggle: View {
    /// The active metering pattern — the segment shown as selected.
    let pattern: MeteringPattern
    /// Called with the chosen pattern when a segment is tapped.
    let onSelect: (MeteringPattern) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var highlight

    var body: some View {
        HStack(spacing: 0) {
            ForEach(MeteringPattern.allCases, id: \.self) { candidate in
                segment(candidate)
            }
        }
        .padding(3)
        .background(.white.opacity(0.08), in: Capsule())
        .overlay(Capsule().strokeBorder(.white.opacity(0.08), lineWidth: 1))
        .animation(reduceMotion ? nil : .snappy, value: pattern)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Metering pattern")
    }

    private func segment(_ candidate: MeteringPattern) -> some View {
        let isSelected = candidate == pattern
        return Button {
            onSelect(candidate)
        } label: {
            Label(candidate.label, systemImage: candidate.systemImage)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(isSelected ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 7)
                .contentShape(Capsule())
                .background {
                    if isSelected {
                        Capsule()
                            .fill(.tint.opacity(0.18))
                            .matchedGeometryEffect(id: "highlight", in: highlight)
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(candidate.label) metering")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

#Preview {
    struct PatternPreview: View {
        @State private var pattern: MeteringPattern = .average
        var body: some View {
            ZStack {
                Color.black.ignoresSafeArea()
                MeteringPatternToggle(pattern: pattern, onSelect: { pattern = $0 })
                    .frame(width: 260)
            }
            .tint(.yellow)
            .preferredColorScheme(.dark)
        }
    }
    return PatternPreview()
}
