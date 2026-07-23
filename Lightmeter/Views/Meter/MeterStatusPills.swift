import SwiftUI

/// The occasional exposure controls — metering pattern and compensation — as two
/// minimal **status pills in the top-left**, over the preview, mirroring the
/// settings gear in the top-right.
///
/// They replace the in-card expanding control strip: instead of two chunky
/// buttons crowding the HUD card, both states are always visible at a glance
/// ("Spot", "+1.0 EV") and either is one tap from its editor. Tapping a pill
/// reveals the *existing* control beneath it — `MeteringPatternToggle`,
/// `CompensationControl` — in a small attached surface, exactly one open at a
/// time; choosing a value collapses it again so the reveal never sits between the
/// photographer and the frame.
///
/// Only placement changed: the pills read already-published `pattern` /
/// `compensation` state and route through the same view-model entry points, so
/// `MeterViewModel`'s behaviour is untouched.
///
/// The open state is *view-local* (`@State`), never `MeterViewModel` state. The
/// guided tour (disabled on this branch) can force-open the editor its step
/// targets via `tourStep`, so the `.compensation` / `.meteringPattern` anchors —
/// which live inside the revealed controls — still resolve.
///
/// Under Reduce Motion the reveal is a plain swap: the height/position animation
/// is dropped so nothing slides.
struct MeterStatusPills: View {
    let model: MeterViewModel
    /// The guided tour's current step, or `nil` when the tour isn't running.
    var tourStep: GuidedTourStep?

    /// Which occasional control a pill exposes — also the reveal identity and the
    /// single-open-at-a-time selector.
    enum Control: Hashable, CaseIterable {
        case pattern
        case compensation

        /// What VoiceOver calls the pill. The glyph and the accent are silent, so
        /// the control's name has to ride here.
        var accessibilityLabel: String {
            switch self {
            case .pattern: "Metering pattern"
            case .compensation: "Exposure compensation"
            }
        }

        /// The state the pill shows — the whole reason it is always visible, so it
        /// is spoken as the pill's value rather than left to the editor.
        @MainActor
        func value(in model: MeterViewModel) -> String {
            switch self {
            case .pattern: model.pattern.label
            case .compensation: model.compensationLabel
            }
        }

        /// The glyph on the pill: the pattern pill wears the active pattern's own
        /// symbol, compensation the fixed plus-minus.
        @MainActor
        func systemImage(in model: MeterViewModel) -> String {
            switch self {
            case .pattern: model.pattern.systemImage
            case .compensation: "plusminus"
            }
        }

        /// What the tap does now — different open and closed, so VoiceOver users
        /// aren't left to infer the pill's state from its label.
        func accessibilityHint(isOpen: Bool) -> String {
            isOpen ? "Hides the control" : "Shows the control"
        }
    }

    /// The editor the guided tour force-opens for `step`, or `nil` for steps whose
    /// control stays in the persistent layout (and when no tour runs). Pure and
    /// exhaustive so a new step can't silently fall through.
    static func tourEditor(for step: GuidedTourStep?) -> Control? {
        switch step {
        case .meteringPattern: .pattern
        case .compensation: .compensation
        case .welcome, .evReadout, .priorityAndChips, .dial, .settings, .none: nil
        }
    }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var openEditor: Control?
    /// The revealed editor's width. The pills float over the preview rather than
    /// stretching a card, so the attached surface is sized to hold the pattern
    /// toggle's two labelled segments comfortably and no wider — the frame stays
    /// clear. Scaled with Dynamic Type so those labels don't truncate at the
    /// larger text sizes.
    @ScaledMetric(relativeTo: .footnote) private var editorWidth: CGFloat = 250

    /// The editor actually shown: the tour override wins while the tour drives a
    /// pill's step; otherwise the photographer's own open editor (untouched by the
    /// tour, keeping the reveal purely view-local).
    private var effectiveOpen: Control? {
        Self.tourEditor(for: tourStep) ?? openEditor
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                pill(.pattern)
                pill(.compensation)
            }
            if let editor = effectiveOpen {
                revealed(editor)
                    .frame(width: editorWidth)
                    // The revealed controls were drawn for the HUD card, which
                    // carries its own legibility scrim; floating them over a live
                    // preview needs the same protection, so they get the pills'
                    // scrim-over-surface treatment too.
                    .modifier(PreviewFloatingBackground())
                    // Slide-and-fade in the non-reduced path; the animation below
                    // is nil'd out under Reduce Motion, turning this into a plain,
                    // instantaneous swap.
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(reduceMotion ? nil : .snappy, value: effectiveOpen)
        // The pills are glass among themselves, the same way the card's controls
        // are, so adjacent surfaces blend as one system on iOS 26.
        .glassGroup()
    }

    private func pill(_ control: Control) -> some View {
        MeterStatusPill(
            control: control,
            model: model,
            isOpen: effectiveOpen == control,
            onTap: { toggle(control) }
        )
    }

    /// Opens an editor, collapsing any other — one-open-at-a-time enforced purely
    /// in view-local state.
    private func toggle(_ control: Control) {
        openEditor = (openEditor == control) ? nil : control
    }

    @ViewBuilder private func revealed(_ control: Control) -> some View {
        switch control {
        case .pattern:
            MeteringPatternToggle(
                pattern: model.pattern,
                onSelect: { pattern in
                    model.setPattern(pattern)
                    // Chosen — collapse, so the reveal doesn't linger over the
                    // frame the photographer is about to meter.
                    openEditor = nil
                }
            )
            .guidedTourAnchor(.meteringPattern)
        case .compensation:
            CompensationControl(
                value: model.compensationLabel,
                isBound: model.isCompensationDialBound,
                onSelect: {
                    model.bindCompensationDial()
                    // Compensation is dialled on the ruler below, so hand the
                    // frame back as soon as the dial is bound.
                    openEditor = nil
                }
            )
            .guidedTourAnchor(.compensation)
        }
    }
}

/// A single status pill: an accent glyph and the control's current state on a
/// small glass capsule. Internal rather than private so `MeterStatusPillsTests`
/// can measure that opening a pill doesn't resize it.
///
/// It derives its glyph and value from the control and the model rather than
/// taking them pre-rendered, so a pill can never be handed one control's name
/// beside another's state.
struct MeterStatusPill: View {
    let control: MeterStatusPills.Control
    let model: MeterViewModel
    /// Whether this pill's editor is revealed — an accent treatment, no resize.
    let isOpen: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 5) {
                // The glyph carries the accent in every state — the pills are
                // always visible, so waiting for the editor to open would leave
                // them reading as plain chrome the whole time they're used.
                Image(systemName: control.systemImage(in: model))
                    .foregroundStyle(.tint)
                Text(control.value(in: model))
                    .foregroundStyle(isOpen ? AnyShapeStyle(.tint) : AnyShapeStyle(.white))
                    .lineLimit(1)
                    // The pair sits over the preview with no card to grow into,
                    // so an accessibility text size shrinks the value rather than
                    // pushing the pills off the frame.
                    .minimumScaleFactor(0.7)
            }
            .font(.footnote.weight(.semibold))
            .padding(.horizontal, 12)
            // A minimal pill that is still a real target: the 44pt minimum is
            // held by the frame, not by fattening the visible capsule.
            .frame(minHeight: 44)
            // `glassEffect` (unlike `background`) contributes no hit region, so
            // pin the tappable area to the whole capsule — the same explicit
            // content shape the settings gear and the chips carry.
            .contentShape(Capsule())
            .modifier(PreviewFloatingBackground())
            .modifier(GlassPillBackground(isActive: isOpen))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(control.accessibilityLabel)
        .accessibilityValue(control.value(in: model))
        .accessibilityAddTraits(isOpen ? .isSelected : [])
        .accessibilityHint(control.accessibilityHint(isOpen: isOpen))
    }
}

/// The legibility scrim for a control floating on the raw camera preview.
///
/// The HUD drawer gets this from `GlassCardBackground`; the pills and their
/// revealed editors sit outside it, directly over a scene that can be a blown-out
/// sky, where glass alone (or the fallback's white-on-nothing fill) washes the
/// white and `.secondary` text out. Composited the same way the drawer's scrim
/// is — behind the content, in front of the surface — so it darkens the
/// refraction rather than sitting under it. Applied *before* the surface modifier
/// at each call site, which is what puts the glass behind it.
struct PreviewFloatingBackground: ViewModifier {
    /// Matched to the drawer's scrim: enough to hold text contrast over a bright
    /// scene without flattening the glass.
    private static let scrimOpacity = 0.3

    func body(content: Content) -> some View {
        content.background(Capsule().fill(.black.opacity(Self.scrimOpacity)))
    }
}

#Preview {
    ZStack {
        // Stand in for a blown-out sky: the case the pills' scrim exists for.
        LinearGradient(colors: [.white, .cyan], startPoint: .top, endPoint: .bottom)
            .ignoresSafeArea()
        MeterStatusPills(model: MeterViewModel(source: CameraLightSource()))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding()
    }
    .tint(.appAccent)
    .preferredColorScheme(.dark)
}
