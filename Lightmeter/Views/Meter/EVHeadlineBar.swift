import SwiftUI

/// The instrument's headline: a floating glass bar pinned to the top of the
/// portrait meter, reading scene brightness as the screen's largest value.
///
/// Left to right: the freeze padlock · `EXPOSURE VALUE @ ISO 100` over the EV
/// value · the solved exposure leg in accent over ISO · the settings gear.
///
/// Three things about that arrangement are decisions rather than drawing:
///
/// - **The caption carries the ISO 100 qualifier** (ADR-0001). The handoff labels
///   the value bare `EXPOSURE VALUE` while putting an ISO readout in the same bar,
///   which reads as EV-at-that-ISO and is wrong. The qualifier sits directly above
///   the number and above the trailing ISO, so it cannot be read as belonging to
///   the other one.
/// - **The padlock and the gear are chrome, not readouts.** The mock has no home
///   for either, and the bar occupies the corner the gear used to float in, so
///   both are rehoused here — at the two ends, at their full 44pt targets, each
///   giving up the glass surface it wore over the preview (see
///   ``FreezeButton/hasSurface``): the panel is already the surface.
/// - **The solved leg is a pure readout; ISO is a control.** The leg is the
///   engine's answer and there is nothing to tap it for. ISO is an input, so
///   tapping it points the ruler dial at the ISO scale — and wears an outline
///   that says so, going accent while the dial is bound to it, which is the same
///   selection-ring vocabulary the exposure chips use.
///
/// The bar's size is fixed by construction: it stretches to the width its caller
/// insets it to, its two glyph ends are frames rather than symbols, and every
/// value is one scale-to-fit line. So neither freezing nor a value that grew a
/// digit can move anything under the photographer's thumb.
///
/// **Four things compete for one row.** Who gives way is declared rather than
/// left to the layout: the headline holds its width (`layoutPriority`) because it
/// is the screen's hero, and the trailing pair — two short values with a generous
/// shrink floor — absorbs the difference.
///
/// At the **accessibility text sizes there is no arrangement of one row that
/// works**: `EXPOSURE VALUE @ ISO 100` alone is wider than any iPhone, so holding
/// the row would crush the largest number on the screen down to `E…`. So the row
/// is abandoned rather than crushed — see ``isStacked(at:)`` — and the trailing
/// pair moves to a second line, where the caption is free to wrap and every value
/// keeps its size. The panel grows taller, which is the one dimension a floating
/// panel over a viewfinder can afford to spend.
struct EVHeadlineBar: View {
    let model: MeterViewModel

    /// Whether the bar reflows onto two lines.
    ///
    /// Keyed on the accessibility sizes rather than on measurement: `ViewThatFits`
    /// would decide from the row's *ideal* width, which for scale-to-fit text is
    /// its unscaled width — so it would abandon the row at the default size too,
    /// where the row is exactly what the design wants. Pure, so the rule is a fact
    /// a test can pin rather than an emergent property of a layout.
    static func isStacked(at size: DynamicTypeSize) -> Bool {
        size.isAccessibilitySize
    }

    /// The gap between the bar's four children, and the inset holding them off
    /// its rounded ends. Small on purpose: the two 44pt targets carry slack of
    /// their own, and the caption is the widest thing in the bar with the least
    /// room to spare on a narrow iPhone.
    static let itemSpacing: CGFloat = 8
    static let horizontalPadding: CGFloat = 8

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var readout: EVHeadlineReadout {
        EVHeadlineReadout(ev: model.ev, triangle: model.triangle)
    }

    private var isStacked: Bool { Self.isStacked(at: dynamicTypeSize) }

    var body: some View {
        VStack(alignment: .leading, spacing: Self.itemSpacing) {
            HStack(spacing: Self.itemSpacing) {
                padlock

                EVHeadlineValue(readout: readout, wrapsCaption: isStacked)
                    // The hero holds its width; the trailing pair gives way.
                    .layoutPriority(1)

                // Pushes what follows to the far end, so the leading block and
                // the trailing one keep their positions whatever either says.
                Spacer(minLength: 0)

                if isStacked == false {
                    trailingPair
                }

                MeterSettingsGear(hasSurface: false)
            }

            if isStacked {
                // The second line, laid out across rather than down: the row it
                // came from was abandoned for width, and spending the height twice
                // over would push the panel into the frame.
                trailingPair
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .padding(.horizontal, Self.horizontalPadding)
        .padding(.vertical, 10)
        .animation(reduceMotion ? nil : .snappy, value: model.triangle)
        .floatingPanel()
    }

    private var padlock: some View {
        FreezeButton(
            isFrozen: model.isFrozen,
            // Mirror `toggleFreeze`'s own guard so the padlock stays enabled in
            // every state the toggle accepts.
            canFreeze: model.latestReading != nil || model.isFrozen,
            onToggle: model.toggleFreeze,
            hasSurface: false
        )
    }

    private var trailingPair: some View {
        EVHeadlineTrailingPair(
            readout: readout,
            isDialBoundToISO: model.boundComponent == .iso,
            isStacked: isStacked,
            onSelectISO: { model.selectChip(.iso) }
        )
    }
}

/// The bar's hero: the scene's brightness, under the caption that says which
/// sensitivity it is quoted at.
///
/// Split out as its own view so the width it needs is measurable — which is what
/// lets a test hold the bar's layout budget rather than trusting a screenshot.
struct EVHeadlineValue: View {
    let readout: EVHeadlineReadout

    /// Whether the caption may wrap instead of shrinking to one line.
    ///
    /// `true` in the stacked layout, where an accessibility text size has already
    /// made one line impossible: the qualifier is the whole reason the caption
    /// exists (ADR-0001), so at the sizes where it cannot both fit and stay
    /// readable, it takes the extra lines rather than the smaller type.
    var wrapsCaption = false

    /// How far this block may shrink before it is failing at its job. The caption
    /// is the wider of the two lines, so this is effectively the caption's floor:
    /// a truncated "EXPOSURE VALUE @ ISO…" has stopped carrying the qualifier.
    static let minimumScale: CGFloat = 0.6

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            caption

            Text(readout.value)
                // The screen's largest value, at the handoff's 30pt. Fixed, because
                // 30pt already outruns any Dynamic Type size — what a large numeral
                // needs from an accessibility size is to keep fitting.
                .font(AppTypography.numeral(fixedSize: 30))
                .foregroundStyle(.white)
                .contentTransition(.numericText())
                .scaledToFitOnOneLine(minimumScale: Self.minimumScale)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(readout.accessibilityLabel)
        .accessibilityValue(readout.accessibilityValue)
    }

    @ViewBuilder private var caption: some View {
        let text = Text(readout.caption)
            // The smallest tier in the app, and the floor the token names.
            .font(.caption2.weight(.medium))
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
            .tracking(1.5)

        if wrapsCaption {
            text.fixedSize(horizontal: false, vertical: true)
        } else {
            text.scaledToFitOnOneLine(minimumScale: Self.minimumScale)
        }
    }
}

/// The bar's trailing end: the solved exposure leg in accent over the
/// photographer's ISO — the complete exposure, readable without moving the eye
/// off the instrument.
struct EVHeadlineTrailingPair: View {
    let readout: EVHeadlineReadout
    /// Whether the ruler dial is currently pointed at the ISO scale — an accent
    /// outline, borrowed from the exposure chips' selection ring.
    let isDialBoundToISO: Bool

    /// Whether the pair is on a line of its own, which is where it lays itself
    /// out across rather than down — see ``EVHeadlineBar/isStacked(at:)``.
    var isStacked = false

    let onSelectISO: () -> Void

    /// How far this pair may shrink. Deeper than the headline's floor on purpose:
    /// these are two short, already-familiar values (`1/500`, `ISO 100`) and this
    /// is the column that gives way when the row runs out of width.
    static let minimumScale: CGFloat = 0.5

    /// The ISO control's height. Smaller than the bar's 44pt ends — it is a value
    /// that happens to be tappable rather than a piece of chrome — but tall enough
    /// that the outline is a target and not a decoration.
    @ScaledMetric(relativeTo: .caption) private var isoTargetHeight: CGFloat = 28

    /// Down in the row, across on a line of its own.
    private var layout: AnyLayout {
        isStacked
            ? AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: 10))
            : AnyLayout(VStackLayout(alignment: .trailing, spacing: 3))
    }

    var body: some View {
        layout {
            Text(readout.solvedValue)
                .font(AppTypography.numeral(.subheadline))
                // The one accented value in the bar: the setting to dial into the
                // camera, which is the only thing here the photographer acts on.
                // A pure readout — there is nothing to tap the engine's answer for.
                .foregroundStyle(.tint)
                .contentTransition(.numericText())
                .scaledToFitOnOneLine(minimumScale: Self.minimumScale)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(readout.solvedAccessibilityLabel)
                .accessibilityValue(readout.solvedAccessibilityValue)

            isoControl
        }
    }

    /// ISO: the bar's one control that does not look like one, so it carries an
    /// outline saying it can be tapped — accent while the dial is bound to it,
    /// hairline otherwise. A stroke inside its own bounds, so binding the dial
    /// costs no layout.
    private var isoControl: some View {
        Button(action: onSelectISO) {
            Text("ISO \(readout.isoValue)")
                .font(AppTypography.numeral(.caption))
                .foregroundStyle(.secondary)
                .contentTransition(.numericText())
                .scaledToFitOnOneLine(minimumScale: Self.minimumScale)
                .padding(.horizontal, 8)
                .frame(minHeight: isoTargetHeight)
                .contentShape(Capsule())
                .overlay(
                    Capsule().strokeBorder(
                        isDialBoundToISO ? AnyShapeStyle(.tint) : AnyShapeStyle(.white.opacity(0.28)),
                        lineWidth: 1
                    )
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(readout.isoAccessibilityLabel)
        .accessibilityValue(readout.isoValue)
        .accessibilityAddTraits(isDialBoundToISO ? .isSelected : [])
        .accessibilityHint(EVHeadlineReadout.isoAccessibilityHint)
    }
}

#Preview {
    ZStack {
        // Stand in for a blown-out sky: the case the panel's scrim exists for.
        LinearGradient(colors: [.white, .cyan], startPoint: .top, endPoint: .bottom)
            .ignoresSafeArea()
        VStack {
            EVHeadlineBar(model: MeterViewModel(source: CameraLightSource()))
                .padding(.horizontal, PortraitMeterLayout.panelInset)
            Spacer()
        }
    }
    .tint(.appAccent)
    .preferredColorScheme(.dark)
}
