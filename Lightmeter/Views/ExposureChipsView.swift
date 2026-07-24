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
/// Every chip is a button routing through `onSelect`, and the dial-bound leg wears
/// a selection ring — drawn as a stroke inside the chip's own bounds, so it costs
/// no layout.
///
/// **Zero reflow.** The photographer taps these by position, often without looking,
/// so a column must never move: `EqualWidthRow` divides the row into exactly equal
/// columns, and the marking rides in a slot of constant size that is reserved
/// whether or not a glyph fills it. Claiming priority is therefore a pure repaint.
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
        EqualWidthRow(spacing: 10) {
            // Values come from `triangle.marking(of:)` — the same convention the
            // hero readout renders the solved leg with, so a leg can never read
            // one way in the chip and another in the hero.
            chip(for: .iso)
            chip(for: .aperture)
            chip(for: .shutter)
        }
        .animation(reduceMotion ? nil : .snappy, value: triangle)
        .animation(reduceMotion ? nil : .snappy, value: boundComponent)
    }

    private func chip(for component: ExposureComponent) -> ExposureValueChip {
        ExposureValueChip(
            value: triangle.marking(of: component) ?? ExposureTriangle.pendingMarking,
            role: Self.role(for: component, triangle: triangle),
            isBound: boundComponent == component,
            component: component,
            onSelect: onSelect
        )
    }

    /// How a chip presents itself — its role in the priority hierarchy.
    enum ChipRole: Equatable {
        /// The exposure leg the photographer holds fixed: accent + closed padlock.
        case held
        /// The leg the current priority mode solves: muted, echoing the hero.
        case solved
        /// A leg that is neither held nor solved (ISO): no marking.
        case plain

        /// The glyph this role puts in the chip's marking slot, or `nil` for the
        /// roles that show nothing. A *closed* padlock, because the leg is pinned by
        /// the photographer — the meter may not move it.
        var markingSymbol: String? {
            self == .held ? "lock.fill" : nil
        }

        /// What VoiceOver reads as the chip's value. The padlock and the accent are
        /// both silent, so the held state rides on the value — otherwise the
        /// variant's central cue would be sighted-only.
        func accessibilityValue(_ value: String) -> String {
            self == .held ? "\(value), held" : value
        }

        /// What VoiceOver reads as the chip's hint. The solved leg is checked first:
        /// it is computed by the app but interactive — tapping it hands control of
        /// the leg to the photographer — so it must read as claimable rather than
        /// "not editable", even in the corner where the dial happens to be bound to
        /// it.
        func accessibilityHint(isBound: Bool) -> String {
            if self == .solved { return "Auto — tap to control" }
            return isBound ? "Bound to dial" : "Bind to dial"
        }
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

    /// The size the marking slot occupies in every chip, glyph or no glyph. Reserved
    /// unconditionally so a role change is a pure repaint. Sized to hold the padlock
    /// at the label floor, which is what it grew to when the 9pt glyph was raised.
    static let markingSlotSize = CGSize(width: 13, height: 13)
}

/// A single exposure-triangle chip: a caption over a value, styled by its role.
/// Every chip is a button — a live leg binds the dial, the solved leg claims
/// priority — so both exposure legs stay reachable at all times.
///
/// Internal rather than private so `ExposureChipsViewTests` can measure that a
/// chip's footprint is identical across roles.
struct ExposureValueChip: View {
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
        .accessibilityLabel(component.caption)
        .accessibilityValue(accessibilityValue)
        .accessibilityAddTraits(isBound ? .isSelected : [])
        .accessibilityHint(accessibilityHint)
    }

    /// The spoken strings live on the role, so what a chip says is testable
    /// without a view — the same shape as the marking glyph beside them.
    private var accessibilityValue: String { role.accessibilityValue(value) }

    private var accessibilityHint: String { role.accessibilityHint(isBound: isBound) }

    private var chipContent: some View {
        VStack(spacing: 3) {
            HStack(spacing: 4) {
                Text(component.caption)
                    .font(.caption2.weight(.semibold))
                    .textCase(.uppercase)
                    .tracking(1)
                    .foregroundStyle(captionStyle)
                    .scaledToFitOnOneLine(minimumScale: 0.7)
                markingSlot
            }

            Text(value)
                .font(AppTypography.numeral(.title3))
                .contentTransition(.numericText())
                .foregroundStyle(valueStyle)
                .scaledToFitOnOneLine()
        }
        .padding(.vertical, 11)
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity)
        // The glass surface contributes no hit region, so pin the tappable area to
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
                if let symbol = role.markingSymbol {
                    Image(systemName: symbol)
                        // The padlock is read, not decoration — it is the only
                        // thing saying which leg is held — so it sits at the
                        // label floor rather than below it.
                        .font(.system(size: AppTypography.labelFloorPointSize, weight: .bold))
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
