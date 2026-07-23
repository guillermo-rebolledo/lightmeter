import SwiftUI

/// The exposure triangle as three value chips — ISO, aperture, shutter — floated
/// over the preview, and the primary priority control. In the portrait variant the
/// marking moves to the leg the photographer *committed to*, so the chips answer
/// "which leg am I holding?" at a glance:
///
///   - **Held** — the exposure leg the photographer pinned (aperture in
///     aperture-priority, shutter in shutter-priority): accent value + a closed
///     padlock. This is the leg the meter is *not* free to move.
///   - **Solved** — the leg the current priority mode computes: muted, because its
///     value simply echoes the hero readout. Tapping it claims priority, so that
///     leg becomes the one you hold and the other becomes solved.
///   - **Plain** — ISO: a set input, but not the priority commitment the padlock
///     reports, so it carries no marking in either mode.
///
/// This inverts the previous AUTO badge, which marked the *solved* leg. The
/// interaction wiring is untouched — every chip is still a button routing through
/// `onSelect`, and the dial-bound leg still wears a selection ring, drawn as a
/// stroke inside the chip's own bounds so it costs no layout.
///
/// **Zero reflow.** All three chips are laid out at equal width, and the marking
/// rides in a slot of constant size that is reserved whether or not a glyph fills
/// it. Changing priority therefore never resizes or shifts a chip — designing out
/// the old defect where the AUTO badge grew the chip it landed on and the row
/// reflowed under the photographer's thumb mid-tap.
struct ExposureChipsView: View {
    let triangle: ExposureTriangle
    /// Which leg the ruler dial is currently bound to, or `nil` while the
    /// compensation overlay owns the dial — the chip to highlight as selected.
    let boundComponent: ExposureComponent?
    /// Called when a chip is tapped. A live leg moves the dial to itself; the
    /// solved leg claims priority. The view leaves that routing to the model.
    let onSelect: (ExposureComponent) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 10) {
            chip(for: .iso, value: triangle.iso.label)
            chip(for: .aperture, value: triangle.aperture.map { "f/\($0.label)" } ?? "—")
            chip(for: .shutter, value: triangle.shutter?.label ?? "—")
        }
        .animation(reduceMotion ? nil : .snappy, value: triangle)
        .animation(reduceMotion ? nil : .snappy, value: boundComponent)
    }

    /// One chip, stretched to an equal share of the row. Every chip is equally
    /// flexible and none of them has a role-dependent ideal width, so the row
    /// always divides into three identical columns.
    private func chip(for component: ExposureComponent, value: String) -> some View {
        ExposureValueChip(
            caption: component.caption,
            value: value,
            role: Self.role(for: component, triangle: triangle),
            isBound: boundComponent == component,
            component: component,
            onSelect: onSelect
        )
        .frame(maxWidth: .infinity)
    }

    /// How a chip presents itself — its role in the priority hierarchy.
    enum ChipRole: Equatable {
        /// The exposure leg the photographer holds fixed: accent + closed padlock.
        case held
        /// The leg the current priority mode solves: muted, echoing the hero.
        case solved
        /// A leg that is neither held nor solved (ISO): no marking.
        case plain
    }

    /// The role of `component`'s chip. ISO is always plain — it is an input, but not
    /// the priority commitment the marking reports. Of the two exposure legs, the
    /// one the engine solved is `solved` and the other is the one being `held`.
    ///
    /// Deliberately independent of the dial binding: which leg the dial drives is a
    /// separate, orthogonal cue (the selection ring), so moving the dial to ISO
    /// doesn't disturb the held/solved reading.
    static func role(for component: ExposureComponent, triangle: ExposureTriangle) -> ChipRole {
        guard component != .iso else { return .plain }
        return triangle.isSolved(component) ? .solved : .held
    }

    /// The glyph `role` puts in the chip's marking slot, or `nil` for the roles that
    /// show nothing. A *closed* padlock, because the leg is pinned by the
    /// photographer — the meter may not move it.
    static func markingSymbol(for role: ChipRole) -> String? {
        role == .held ? "lock.fill" : nil
    }

    /// The size the marking slot occupies in every chip, glyph or no glyph. Reserved
    /// unconditionally so a role change is a pure repaint.
    static let markingSlotSize = CGSize(width: 11, height: 12)
}

/// A single exposure-triangle chip: a caption over a value, styled by its role.
/// Every chip is a button — a live leg binds the dial, the solved leg claims
/// priority — so both exposure legs stay reachable at all times.
///
/// Internal rather than private so `ExposureChipsViewTests` can measure that a
/// chip's footprint is identical across roles.
struct ExposureValueChip: View {
    let caption: String
    let value: String
    let role: ExposureChipsView.ChipRole
    /// Whether the ruler dial is currently bound to this leg — orthogonal to
    /// `role`, and shown as a ring rather than a marking.
    let isBound: Bool
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
        .accessibilityValue(accessibilityValue)
        .accessibilityAddTraits(isBound ? .isSelected : [])
        .accessibilityHint(accessibilityHint)
    }

    /// The padlock is silent to VoiceOver as a glyph, so the held state rides on the
    /// value instead — otherwise the marking would be sighted-only.
    private var accessibilityValue: String {
        role == .held ? "\(value), held" : value
    }

    private var accessibilityHint: String {
        if isBound { return "Bound to dial" }
        // The solved leg is computed by the app but interactive — tapping it hands
        // control of this leg to the photographer, so it reads as claimable rather
        // than "not editable".
        return role == .solved ? "Auto — tap to control" : "Bind to dial"
    }

    private var chipContent: some View {
        VStack(spacing: 3) {
            HStack(spacing: 4) {
                Text(caption)
                    .font(.caption2.weight(.semibold))
                    .textCase(.uppercase)
                    .tracking(1)
                    .foregroundStyle(captionStyle)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                markingSlot
            }

            Text(value)
                .font(.title3.weight(.semibold).monospacedDigit())
                .contentTransition(.numericText())
                .foregroundStyle(valueStyle)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .padding(.vertical, 11)
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity)
        // `glassEffect` contributes no hit region, so pin the tappable area to
        // the full chip; without it, tapping a chip only registers on the
        // caption/value text.
        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .modifier(GlassChipBackground(isBound: isBound))
    }

    /// The marking: a closed padlock beside the caption on the held leg. The slot is
    /// a fixed-size clear spacer with the glyph laid *over* it, rather than the glyph
    /// wearing the frame — an unmarked chip would otherwise resolve to an `EmptyView`,
    /// which the caption's `HStack` drops entirely (slot width *and* its spacing),
    /// growing the chip the moment a padlock appears. Overlaying keeps the slot in
    /// the layout unconditionally, so a role change is a pure repaint.
    private var markingSlot: some View {
        Color.clear
            .frame(
                width: ExposureChipsView.markingSlotSize.width,
                height: ExposureChipsView.markingSlotSize.height
            )
            .overlay {
                if let symbol = ExposureChipsView.markingSymbol(for: role) {
                    Image(systemName: symbol)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.tint)
                }
            }
            .accessibilityHidden(true)
    }

    // The held leg carries the accent — the same accent the padlock and the dial
    // wear — so the commitment reads instantly; the solved leg is muted throughout
    // because its value is already the hero; ISO is plain white-on-glass. Erased to
    // `AnyShapeStyle` so the branches share a type.
    private var captionStyle: AnyShapeStyle {
        switch role {
        case .held: AnyShapeStyle(.tint)
        case .solved: AnyShapeStyle(.secondary)
        case .plain: AnyShapeStyle(.secondary)
        }
    }

    private var valueStyle: AnyShapeStyle {
        switch role {
        case .held: AnyShapeStyle(.tint)
        case .solved: AnyShapeStyle(.secondary)
        case .plain: AnyShapeStyle(.white)
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
