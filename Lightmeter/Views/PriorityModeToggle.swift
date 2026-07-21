import SwiftUI

/// The priority-mode control: a two-segment glass pill that switches which leg
/// the photographer locks and which the engine solves. The selected segment
/// carries an accent-tinted highlight that slides between the two, echoing the
/// arc dial's mechanical feel. Selecting the already-active segment is a no-op.
struct PriorityModeToggle: View {
    /// The active priority mode — the segment shown as selected.
    let mode: PriorityMode
    /// Called with the chosen mode when a segment is tapped.
    let onSelect: (PriorityMode) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var highlight

    var body: some View {
        HStack(spacing: 0) {
            ForEach(PriorityMode.allCases, id: \.self) { candidate in
                segment(candidate)
            }
        }
        .padding(3)
        .background(.white.opacity(0.08), in: Capsule())
        .overlay(Capsule().strokeBorder(.white.opacity(0.08), lineWidth: 1))
        .animation(reduceMotion ? nil : .snappy, value: mode)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Priority mode")
    }

    private func segment(_ candidate: PriorityMode) -> some View {
        let isSelected = candidate == mode
        return Button {
            onSelect(candidate)
        } label: {
            Text(candidate.label)
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
        .accessibilityLabel("\(candidate.label) priority")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

#Preview {
    struct TogglePreview: View {
        @State private var mode: PriorityMode = .aperturePriority
        var body: some View {
            ZStack {
                Color.black.ignoresSafeArea()
                PriorityModeToggle(mode: mode, onSelect: { mode = $0 })
                    .frame(width: 260)
            }
            .tint(.yellow)
            .preferredColorScheme(.dark)
        }
    }
    return TogglePreview()
}
