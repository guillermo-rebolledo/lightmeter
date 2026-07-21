import SwiftUI

/// The exposure triangle as three value chips — ISO, aperture, shutter — floated
/// over the preview. The solved leg (shutter in aperture-priority) is tinted and
/// marked non-editable; the two set legs read as plain values. Values animate as
/// the light changes.
struct ExposureChipsView: View {
    let triangle: ExposureTriangle

    var body: some View {
        HStack(spacing: 10) {
            ValueChip(
                caption: "ISO",
                value: triangle.iso.label,
                isSolved: triangle.isSolved(.iso)
            )
            ValueChip(
                caption: "Aperture",
                value: "f/\(triangle.aperture.label)",
                isSolved: triangle.isSolved(.aperture)
            )
            ValueChip(
                caption: "Shutter",
                value: triangle.shutter?.label ?? "—",
                isSolved: triangle.isSolved(.shutter)
            )
        }
        .animation(.snappy, value: triangle)
    }
}

/// A single exposure-triangle chip: a caption over a value. When it represents
/// the solved leg it is accent-tinted and announced as solved and non-editable.
private struct ValueChip: View {
    let caption: String
    let value: String
    let isSolved: Bool

    var body: some View {
        VStack(spacing: 3) {
            Text(caption)
                .font(.caption2.weight(.semibold))
                .textCase(.uppercase)
                .tracking(1)
                .foregroundStyle(captionStyle)

            Text(value)
                .font(.title3.weight(.semibold).monospacedDigit())
                .contentTransition(.numericText())
                .foregroundStyle(valueStyle)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 11)
        .padding(.horizontal, 8)
        .background(chipBackground)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(caption)
        .accessibilityValue(value)
        .accessibilityHint(isSolved ? "Solved, not editable" : "")
    }

    // The solved leg is accent-tinted throughout; the set legs read as plain
    // white-on-glass. Erased to `AnyShapeStyle` so both branches share a type.
    private var captionStyle: AnyShapeStyle {
        isSolved ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary)
    }

    private var valueStyle: AnyShapeStyle {
        isSolved ? AnyShapeStyle(.tint) : AnyShapeStyle(.white)
    }

    private var chipBackground: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(isSolved ? AnyShapeStyle(.tint.opacity(0.16)) : AnyShapeStyle(.white.opacity(0.08)))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(.tint.opacity(isSolved ? 0.55 : 0), lineWidth: 1)
            )
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        ExposureChipsView(
            triangle: ExposureEngine.solvedTriangle(evAtISO100: 15, iso: 100, aperture: 16)
        )
        .padding()
    }
    .tint(.yellow)
    .preferredColorScheme(.dark)
}
