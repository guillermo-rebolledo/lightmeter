import SwiftUI

/// The exposure triangle as three value chips — ISO, aperture, shutter — floated
/// over the preview. The solved leg (shutter in aperture-priority) is tinted and
/// marked non-editable; the two set legs read as plain values and can be tapped
/// to bind the arc dial. The chip the dial is bound to is highlighted. Values
/// animate as the light changes.
struct ExposureChipsView: View {
    let triangle: ExposureTriangle
    /// Which leg the arc dial is currently bound to, or `nil` when no dial is
    /// active — the chip to highlight as selected.
    let boundComponent: ExposureComponent?
    /// Called when an editable chip is tapped, to bind (or unbind) the dial.
    let onSelect: (ExposureComponent) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 10) {
            ValueChip(
                caption: "ISO",
                value: triangle.iso.label,
                component: .iso,
                isSolved: triangle.isSolved(.iso),
                isBound: boundComponent == .iso,
                onSelect: onSelect
            )
            ValueChip(
                caption: "Aperture",
                value: triangle.aperture.map { "f/\($0.label)" } ?? "—",
                component: .aperture,
                isSolved: triangle.isSolved(.aperture),
                isBound: boundComponent == .aperture,
                onSelect: onSelect
            )
            ValueChip(
                caption: "Shutter",
                value: triangle.shutter?.label ?? "—",
                component: .shutter,
                isSolved: triangle.isSolved(.shutter),
                isBound: boundComponent == .shutter,
                onSelect: onSelect
            )
        }
        .animation(.snappy, value: triangle)
        .animation(reduceMotion ? nil : .snappy, value: boundComponent)
    }
}

/// A single exposure-triangle chip: a caption over a value. The solved leg is
/// accent-tinted, announced as solved and non-editable, and not tappable. A set
/// leg is a button that binds the arc dial; while bound it shows a selected ring.
private struct ValueChip: View {
    let caption: String
    let value: String
    let component: ExposureComponent
    let isSolved: Bool
    let isBound: Bool
    let onSelect: (ExposureComponent) -> Void

    var body: some View {
        if isSolved {
            // The solved leg is read-only — a plain, non-interactive readout.
            chipContent
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(caption)
                .accessibilityValue(value)
                .accessibilityHint("Solved, not editable")
        } else {
            Button {
                onSelect(component)
            } label: {
                chipContent
            }
            .buttonStyle(.plain)
            .accessibilityLabel(caption)
            .accessibilityValue(value)
            .accessibilityAddTraits(isBound ? .isSelected : [])
            .accessibilityHint(isBound ? "Bound to dial" : "Bind to dial")
        }
    }

    private var chipContent: some View {
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
    }

    // The solved leg is accent-tinted throughout; the set legs read as plain
    // white-on-glass. Erased to `AnyShapeStyle` so both branches share a type.
    private var captionStyle: AnyShapeStyle {
        isSolved ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary)
    }

    private var valueStyle: AnyShapeStyle {
        isSolved ? AnyShapeStyle(.tint) : AnyShapeStyle(.white)
    }

    // Solved: a faint accent wash. Bound: a brighter fill with an accent ring so
    // it reads as the active dial. Otherwise plain white-on-glass.
    private var chipBackground: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(fillStyle)
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(.tint.opacity(strokeOpacity), lineWidth: isBound ? 1.5 : 1)
            )
    }

    private var fillStyle: AnyShapeStyle {
        if isSolved { return AnyShapeStyle(.tint.opacity(0.16)) }
        if isBound { return AnyShapeStyle(.tint.opacity(0.22)) }
        return AnyShapeStyle(.white.opacity(0.08))
    }

    private var strokeOpacity: Double {
        if isBound { return 0.9 }
        if isSolved { return 0.55 }
        return 0
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        ExposureChipsView(
            triangle: ExposureEngine.solvedTriangle(
                mode: .aperturePriority, evAtISO100: 15, iso: 100, aperture: 16, shutter: 1.0 / 125
            ),
            boundComponent: .aperture,
            onSelect: { _ in }
        )
        .padding()
    }
    .tint(.yellow)
    .preferredColorScheme(.dark)
}
