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

    /// The revealed editor's width. The pills float over the preview rather than
    /// stretching a card, so the attached surface is sized to hold the pattern
    /// toggle's two segments comfortably and no wider — the frame stays clear.
    private static let editorWidth: CGFloat = 220

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var openEditor: Control?

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
                    .frame(width: Self.editorWidth)
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
            systemImage: control.systemImage(in: model),
            value: control.value(in: model),
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

/// A single status pill: a glyph and the control's current state on a small glass
/// capsule. Internal rather than private so `MeterStatusPillsTests` can measure
/// that opening a pill doesn't resize it.
struct MeterStatusPill: View {
    let control: MeterStatusPills.Control
    let systemImage: String
    /// The control's current state, shown on the pill and spoken as its value.
    let value: String
    /// Whether this pill's editor is revealed — an accent treatment, no resize.
    let isOpen: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 5) {
                Image(systemName: systemImage)
                Text(value)
                    .lineLimit(1)
            }
            .font(.footnote.weight(.semibold))
            .foregroundStyle(isOpen ? AnyShapeStyle(.tint) : AnyShapeStyle(.white))
            .padding(.horizontal, 12)
            // A minimal pill that is still a real target: the 44pt minimum is
            // held by the frame, not by fattening the visible capsule.
            .frame(minHeight: 44)
            // `glassEffect` (unlike `background`) contributes no hit region, so
            // pin the tappable area to the whole capsule — the same explicit
            // content shape the settings gear and the chips carry.
            .contentShape(Capsule())
            .modifier(GlassPillBackground(isActive: isOpen))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(control.accessibilityLabel)
        .accessibilityValue(value)
        .accessibilityAddTraits(isOpen ? .isSelected : [])
        .accessibilityHint(control.accessibilityHint(isOpen: isOpen))
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        VStack(alignment: .leading) {
            MeterStatusPill(
                control: .pattern,
                systemImage: MeteringPattern.spot.systemImage,
                value: MeteringPattern.spot.label,
                isOpen: false,
                onTap: {}
            )
            MeterStatusPill(
                control: .compensation,
                systemImage: "plusminus",
                value: "+1.0 EV",
                isOpen: true,
                onTap: {}
            )
        }
        .padding()
    }
    .tint(.appAccent)
    .preferredColorScheme(.dark)
}
