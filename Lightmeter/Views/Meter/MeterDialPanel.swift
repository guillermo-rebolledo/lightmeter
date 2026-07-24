import SwiftUI

/// The instrument face: a floating glass panel at the bottom of the portrait
/// meter, naming the value the photographer is currently turning, showing it as
/// the panel's large numeral, and running it along a graduated rule under a fixed
/// needle. Advisories come along underneath, in a slot that is always there.
///
/// It replaces the docked HUD drawer in portrait. The drawer's hero was the
/// *solved* leg, which the EV headline bar has read since #96; what the drawer
/// had that nothing else does is the dial, so the panel is built around it and
/// the duplicate hero goes.
///
/// Three things about it are decisions rather than drawing:
///
/// - **The headline is the dial's own marking, not the chip's.** An aperture
///   reads `8` here and `f/8` on a chip, because the number over the rule has to
///   be the number *on* the rule — the needle points at `8`, and a headline
///   saying `f/8` would be the same value written two ways an inch apart. The
///   caption above it says which leg it is, which is what the `f/` was carrying.
/// - **The headline is silent to VoiceOver.** It is a bigger rendering of what
///   the dial element beneath it already says, and that element is the one you
///   can act on — announcing both would hand a VoiceOver user the same value
///   twice, once from something that does nothing.
/// - **The advisory slot is reserved whether or not there is an advisory.** The
///   panel floats at the bottom of the screen with the dial directly above the
///   footer, so a warning arriving mid-drag would otherwise lift the rule out
///   from under the thumb that is turning it.
///
/// The panel's height is fixed by construction: the caption is one line, the
/// numeral is a fixed size that scales to fit, the rule reserves its rows, and
/// the footer reserves its line. So neither an advisory, nor a value that grew a
/// digit, nor re-pointing the dial at another leg can move it.
struct MeterDialPanel: View {
    let model: MeterViewModel
    /// The advisories snapshot to display — frozen while the tour runs.
    let advisories: [ExposureAdvisory]
    let isTourActive: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// The panel's inner padding. Wider at the sides than top and bottom: the rule
    /// fades out at both ends rather than stopping at a margin, so horizontal
    /// padding is doing less work here than it does on a row of controls.
    private static let horizontalPadding: CGFloat = 16
    private static let verticalPadding: CGFloat = 14

    /// The gap between the headline, the rule, and the footer.
    private static let rowSpacing: CGFloat = 10

    var body: some View {
        VStack(spacing: Self.rowSpacing) {
            headline
            MeterDialHost(model: model)
            MeterAdvisoryFooter(advisories: advisories, isTourActive: isTourActive)
        }
        .padding(.horizontal, Self.horizontalPadding)
        .padding(.vertical, Self.verticalPadding)
        .floatingPanel()
    }

    /// What the dial is turning, and where it is now.
    private var headline: some View {
        VStack(spacing: 2) {
            Text(model.dialCaption ?? "")
                // The smallest tier in the app, and the floor the token names —
                // the same caption treatment the EV headline bar wears, because
                // these are the screen's two panels and its two large values.
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(1.5)
                .scaledToFitOnOneLine(minimumScale: 0.7)

            Text(model.dialValue ?? ExposureTriangle.pendingMarking)
                // The screen's second-largest value, under the bar's 30pt hero.
                // Fixed, because 26pt already outruns any Dynamic Type size —
                // what a large numeral needs from an accessibility size is to
                // keep fitting.
                .font(AppTypography.numeral(fixedSize: 26))
                .foregroundStyle(.white)
                // It counts rather than cutting as the rule sweeps under the
                // thumb — the numeric transition needs an ambient animation to
                // drive it, which the spring below supplies. This is a value the
                // photographer *moves*, so it springs (like the bar's solved leg)
                // rather than easing the way a metered readout does (#91's split
                // by causality), and it collapses to a snap under Reduce Motion.
                .contentTransition(.numericText())
                .scaledToFitOnOneLine()
        }
        .frame(maxWidth: .infinity)
        .animation(reduceMotion ? nil : .snappy, value: model.dialValue)
        // Silent: the dial below is the same caption and the same value, on the
        // element a VoiceOver user can actually adjust.
        .accessibilityHidden(true)
    }
}

/// The panel's footer: exposure advisories in a slot whose height never changes.
///
/// `AdvisoriesView` draws nothing when there is nothing to warn about, which
/// collapses its own height *and* its parent's spacing around it. That is right
/// for a drawer that grows off a screen edge and wrong for a floating panel: the
/// rule the photographer is dragging sits directly above this line, and a tripod
/// warning arriving mid-drag would pull it upward under their thumb.
///
/// So the slot is reserved by a hidden advisory of the same shape rather than by
/// a hard-coded height — which is also what makes it scale with Dynamic Type
/// without naming a size of its own. When there is no advisory the reserved line
/// reads as the panel's bottom padding.
struct MeterAdvisoryFooter: View {
    let advisories: [ExposureAdvisory]
    let isTourActive: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Stands in for whatever advisory may arrive. Any of them would do — the
    /// compact line is one line of `.caption` beside one glyph whatever it says —
    /// so this is a placeholder for a *shape*, not a message.
    private static let reservedShape: [ExposureAdvisory] = [.tripodRecommended]

    var body: some View {
        ZStack(alignment: .leading) {
            AdvisoriesView(advisories: Self.reservedShape, isCompact: true)
                .hidden()
                .accessibilityHidden(true)

            MeterAdvisories(advisories: advisories, isTourActive: isTourActive, isCompact: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        // An advisory is something the *meter* reports rather than something the
        // photographer moved, so it eases in (#91's split by causality) instead of
        // springing. The slot it appears in was already there, so nothing moves —
        // only the warning itself fades up.
        .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: advisories)
    }
}

#Preview {
    ZStack {
        // Stand in for a blown-out sky: the case the panel's scrim exists for.
        LinearGradient(colors: [.white, .cyan], startPoint: .top, endPoint: .bottom)
            .ignoresSafeArea()
        VStack {
            Spacer()
            MeterDialPanel(
                model: MeterViewModel(source: CameraLightSource()),
                advisories: [.tripodRecommended],
                isTourActive: false
            )
            .padding(.horizontal, PortraitMeterLayout.panelInset)
        }
    }
    .tint(.appAccent)
    .preferredColorScheme(.dark)
}
