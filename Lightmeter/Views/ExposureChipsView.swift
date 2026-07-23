import SwiftUI

/// The exposure triangle as three value chips — ISO, aperture, shutter — floated
/// over the preview, and now the primary priority control. Each chip reads its
/// role at a glance:
///
///   - **Bound** — the leg the ruler dial currently drives: accent value + a
///     selected ring, visually tied to the dial below by the shared accent.
///   - **Editable** — the other live leg (e.g. ISO): plain glass, full opacity,
///     clearly tappable to move the dial to it.
///   - **AUTO** — the leg the current priority mode solves: an AUTO badge and
///     muted styling (no padlock — the app is *driving* this leg, not pinning it).
///     Tapping it claims priority, so that leg becomes the one you control and the
///     other exposure leg becomes AUTO.
///
/// Both exposure legs are always live — one to edit, one to claim — so every chip
/// is a button. Exactly one chip wears the ring at a time: the bound leg, unless
/// the transient compensation overlay owns the dial. Values animate as the light
/// changes.
struct ExposureChipsView: View {
    let triangle: ExposureTriangle
    /// Which leg the ruler dial is currently bound to, or `nil` while the
    /// compensation overlay owns the dial — the chip to highlight as selected.
    let boundComponent: ExposureComponent?
    /// Called when a chip is tapped. An editable leg moves the dial to itself; the
    /// AUTO leg claims priority. The view leaves that routing to the model.
    let onSelect: (ExposureComponent) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 10) {
            ValueChip(
                caption: "ISO",
                value: triangle.iso.label,
                role: Self.role(for: .iso, triangle: triangle, boundComponent: boundComponent),
                component: .iso,
                onSelect: onSelect
            )
            ValueChip(
                caption: "Aperture",
                value: triangle.aperture.map { "f/\($0.label)" } ?? "—",
                role: Self.role(for: .aperture, triangle: triangle, boundComponent: boundComponent),
                component: .aperture,
                onSelect: onSelect
            )
            ValueChip(
                caption: "Shutter",
                value: triangle.shutter?.label ?? "—",
                role: Self.role(for: .shutter, triangle: triangle, boundComponent: boundComponent),
                component: .shutter,
                onSelect: onSelect
            )
        }
        .animation(reduceMotion ? nil : .snappy, value: triangle)
        .animation(reduceMotion ? nil : .snappy, value: boundComponent)
    }

    /// How a chip presents itself — its role in the priority/editing hierarchy.
    enum ChipRole: Equatable {
        /// The leg the ruler dial currently drives: accent value + selected ring.
        case bound
        /// A live leg that isn't currently bound: plain glass, tap to bind.
        case editable
        /// The leg the current priority mode solves: AUTO badge + muted styling,
        /// tap to claim priority.
        case auto
    }

    /// The role of `component`'s chip. The solved leg is always AUTO (a bound leg
    /// is never solved, so this is checked first); otherwise the leg the dial is
    /// bound to is `bound` and any other live leg is `editable`. With the dial off
    /// on the compensation overlay (`boundComponent == nil`) no chip is bound, so
    /// the two non-solved legs both read as `editable`.
    static func role(
        for component: ExposureComponent,
        triangle: ExposureTriangle,
        boundComponent: ExposureComponent?
    ) -> ChipRole {
        if triangle.isSolved(component) { return .auto }
        if boundComponent == component { return .bound }
        return .editable
    }
}

/// A single exposure-triangle chip: a caption over a value, styled by its role.
/// Every chip is a button now — the editable leg binds the dial, the AUTO leg
/// claims priority — so both exposure legs stay reachable at all times.
private struct ValueChip: View {
    let caption: String
    let value: String
    let role: ExposureChipsView.ChipRole
    let component: ExposureComponent
    let onSelect: (ExposureComponent) -> Void

    var body: some View {
        Button {
            onSelect(component)
        } label: {
            chipContent
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(caption)
        .accessibilityValue(value)
        .accessibilityAddTraits(role == .bound ? .isSelected : [])
        .accessibilityHint(accessibilityHint)
    }

    private var accessibilityHint: String {
        switch role {
        case .bound: "Bound to dial"
        case .editable: "Bind to dial"
        // The AUTO leg is computed by the app but now interactive — tapping it
        // hands control of this leg to the photographer, so it reads as claimable
        // rather than "not editable".
        case .auto: "Auto — tap to control"
        }
    }

    private var chipContent: some View {
        VStack(spacing: 3) {
            HStack(spacing: 4) {
                Text(caption)
                    .font(.caption2.weight(.semibold))
                    .textCase(.uppercase)
                    .tracking(1)
                    .foregroundStyle(captionStyle)
                if role == .auto {
                    autoBadge
                }
            }

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
        // `glassEffect` contributes no hit region, so pin the tappable area to
        // the full chip; without it, tapping a chip only registers on the
        // caption/value text.
        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .modifier(GlassChipBackground(isBound: role == .bound))
    }

    /// The AUTO marker: a small muted pill next to the caption, signalling the app
    /// is driving this leg. Deliberately not a padlock — the leg is claimable, not
    /// pinned.
    private var autoBadge: some View {
        Text("AUTO")
            .font(.system(size: 8, weight: .heavy))
            .tracking(0.5)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 4)
            .padding(.vertical, 1)
            .background(.white.opacity(0.12), in: Capsule())
    }

    // The bound leg carries the accent, tying it to the dial below; the editable
    // leg reads as plain white-on-glass; the AUTO leg is muted throughout. Erased
    // to `AnyShapeStyle` so the branches share a type.
    private var captionStyle: AnyShapeStyle {
        switch role {
        case .bound: AnyShapeStyle(.tint)
        case .editable: AnyShapeStyle(.secondary)
        case .auto: AnyShapeStyle(.secondary)
        }
    }

    private var valueStyle: AnyShapeStyle {
        switch role {
        case .bound: AnyShapeStyle(.tint)
        case .editable: AnyShapeStyle(.white)
        case .auto: AnyShapeStyle(.secondary)
        }
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
    .tint(.appAccent)
    .preferredColorScheme(.dark)
}
