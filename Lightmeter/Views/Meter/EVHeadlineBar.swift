import SwiftUI

/// The instrument's headline: a floating glass bar pinned to the top of the
/// portrait meter, reading scene brightness as the screen's largest value.
///
/// Left to right: the freeze padlock · `EXPOSURE VALUE @ ISO 100` over the EV
/// value · the solved exposure leg in accent · the settings gear.
///
/// Three things about that arrangement are decisions rather than drawing:
///
/// - **The caption carries the ISO 100 qualifier** (ADR-0001). The handoff labels
///   the value bare `EXPOSURE VALUE`, which reads as EV-at-some-ISO and is wrong.
///   The qualifier sits directly above the number, so the reference is read as
///   part of the value rather than left to be inferred.
/// - **The padlock and the gear are chrome, not readouts.** The mock has no home
///   for either, and the bar occupies the corner the gear used to float in, so
///   both are rehoused here — at the two ends, at their full 44pt targets, each
///   giving up the glass surface it wore over the preview (see
///   ``FreezeButton/hasSurface``): the panel is already the surface.
/// - **The trailing end is the solved leg alone — a pure readout.** ISO used to
///   ride here as the bar's one control, but it has moved down to the mode row
///   beside aperture and shutter (the things the dial turns), so the bar's
///   trailing end now shows only the engine's answer, in accent. That both puts
///   ISO under the thumb with everything else it dials and recovers headline space
///   the ISO control was spending.
///
/// The bar's size is fixed by construction: it stretches to the width its caller
/// insets it to, its two glyph ends are frames rather than symbols, and every
/// value is one scale-to-fit line. So neither freezing nor a value that grew a
/// digit can move anything under the photographer's thumb.
///
/// **Four things compete for one row.** Who gives way is declared rather than
/// left to the layout: the headline holds its width (`layoutPriority`) because it
/// is the screen's hero, and the trailing solved leg — one short value with a
/// generous shrink floor — absorbs the difference.
///
/// At the **accessibility text sizes there is no arrangement of one row that
/// works**: `EXPOSURE VALUE @ ISO 100` alone is wider than any iPhone, so holding
/// the row would crush the largest number on the screen down to `E…`. So the row
/// is abandoned rather than crushed — see ``Arrangement`` — and the solved leg
/// moves to a second line, where the caption is free to wrap and every value
/// keeps its size. The panel grows taller, which is the one dimension a floating
/// panel over a viewfinder can afford to spend.
struct EVHeadlineBar: View {
    let model: MeterViewModel

    /// How the bar lays itself out — one row, or two.
    ///
    /// Keyed on the accessibility sizes rather than on measurement: `ViewThatFits`
    /// would decide from the row's *ideal* width, which for scale-to-fit text is
    /// its unscaled width — so it would abandon the row at the default size too,
    /// where the row is exactly what the design wants. Pure, so the rule is a fact
    /// a test can pin rather than an emergent property of a layout.
    enum Arrangement {
        /// Padlock · headline · trailing pair · gear, all on one line.
        case row
        /// Padlock · headline, then the solved leg and the gear beneath. The
        /// chrome follows the value down rather than staying on the first line,
        /// so reading order — by eye or by VoiceOver — is still EV, solved leg,
        /// gear.
        case stacked

        init(at size: DynamicTypeSize) {
            self = size.isAccessibilitySize ? .stacked : .row
        }
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

    private var arrangement: Arrangement { Arrangement(at: dynamicTypeSize) }

    var body: some View {
        VStack(alignment: .leading, spacing: Self.itemSpacing) {
            HStack(spacing: Self.itemSpacing) {
                padlock

                EVHeadlineValue(readout: readout, arrangement: arrangement)
                    // The hero holds its width; the trailing pair gives way.
                    .layoutPriority(1)

                // Pushes what follows to the far end, so the leading block and
                // the trailing one keep their positions whatever either says.
                Spacer(minLength: 0)

                if arrangement == .row {
                    solvedLeg
                    gear
                }
            }

            if arrangement == .stacked {
                // The second line: the solved leg, with the gear following it to
                // the end of the line so the chrome is still read after the value
                // rather than between the value and the headline above it.
                HStack(spacing: Self.itemSpacing) {
                    Spacer(minLength: 0)
                    solvedLeg
                    gear
                }
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
            canFreeze: model.canFreeze,
            onToggle: model.toggleFreeze,
            hasSurface: false
        )
    }

    /// Both ends give up the glass surface they wear over the preview: the panel
    /// is already the surface separating them from the scene.
    private var gear: some View {
        MeterSettingsGear(hasSurface: false)
    }

    private var solvedLeg: some View {
        EVHeadlineSolvedLeg(readout: readout)
    }
}

/// The bar's hero: the scene's brightness, under the caption that says which
/// sensitivity it is quoted at.
///
/// Split out as its own view so the width it needs is measurable — which is what
/// lets a test hold the bar's layout budget rather than trusting a screenshot.
struct EVHeadlineValue: View {
    let readout: EVHeadlineReadout

    /// Which arrangement of the bar this block is sitting in. Stacked, the caption
    /// wraps instead of shrinking: an accessibility text size has already made one
    /// line impossible, and the qualifier is the whole reason the caption exists
    /// (ADR-0001), so it takes the extra lines rather than the smaller type.
    var arrangement = EVHeadlineBar.Arrangement.row

    /// How far this block may shrink before it is failing at its job. The caption
    /// is the wider of the two lines, so this is effectively the caption's floor:
    /// a truncated "EXPOSURE VALUE @ ISO…" has stopped carrying the qualifier.
    static let minimumScale: CGFloat = 0.6

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            caption
            value
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(readout.accessibilityLabel)
        .accessibilityValue(readout.accessibilityValue)
    }

    /// The headline number, typeset as a small `EV` unit over the large figure —
    /// so `EV` reads as a prefix on the value rather than a same-size word held a
    /// digit away from it. Baseline-aligned with a tight custom gap; the number
    /// keeps its tabular figures and count-up transition, the whole pair scaling
    /// as one line so tightening the label costs the readout none of its stability.
    private var value: some View {
        HStack(alignment: .firstTextBaseline, spacing: Self.unitGap) {
            Text(EVHeadlineReadout.unit)
                // A quiet unit prefix, not a second headline: the caption tier the
                // app names, so the eye lands on the number beside it.
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            Text(readout.evValue)
                // The screen's largest value, at the handoff's 30pt. Fixed, because
                // 30pt already outruns any Dynamic Type size — what a large numeral
                // needs from an accessibility size is to keep fitting.
                .font(AppTypography.numeral(fixedSize: 30))
                .foregroundStyle(.white)
                .contentTransition(.numericText())
        }
        // The unit and the number scale together as one line, so the tight gap
        // between them is preserved rather than shrinking one run and not the other.
        .scaledToFitOnOneLine(minimumScale: Self.minimumScale)
    }

    /// The gap between the small `EV` and the number — tight on purpose, so the
    /// unit reads as belonging *to* the figure rather than floating a digit away.
    private static let unitGap: CGFloat = 4

    @ViewBuilder private var caption: some View {
        let text = Text(readout.caption)
            // The smallest tier in the app, and the floor the token names.
            .font(.caption2.weight(.medium))
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
            .tracking(1.5)

        switch arrangement {
        case .row: text.scaledToFitOnOneLine(minimumScale: Self.minimumScale)
        case .stacked: text.fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// The bar's trailing end: the solved exposure leg in accent — the engine's
/// answer, readable without moving the eye off the instrument.
///
/// A pure readout: there is nothing to tap the engine's answer for. ISO used to
/// share this end as the bar's one control, but it has moved to the mode row
/// beside the other legs the dial turns, leaving the leg alone here.
struct EVHeadlineSolvedLeg: View {
    let readout: EVHeadlineReadout

    /// How far the leg may shrink. Deeper than the headline's floor on purpose:
    /// it is one short, already-familiar value (`1/500`, `f/16`) and it is the
    /// column that gives way when the row runs out of width.
    static let minimumScale: CGFloat = 0.5

    var body: some View {
        Text(readout.solvedValue)
            .font(AppTypography.numeral(.subheadline))
            // The one accented value in the bar: the setting to dial into the
            // camera, which is the only thing here the photographer acts on.
            .foregroundStyle(.tint)
            .contentTransition(.numericText())
            .scaledToFitOnOneLine(minimumScale: Self.minimumScale)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(readout.solvedAccessibilityLabel)
            .accessibilityValue(readout.solvedAccessibilityValue)
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
