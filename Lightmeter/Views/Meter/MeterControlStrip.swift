import SwiftUI

/// The occasional exposure controls — compensation and metering pattern — lifted
/// out of the persistent compact card into an inline expanding strip. Priority is
/// no longer here: the exposure chips are the priority control now, claimed by
/// tapping the AUTO leg. A compact row of icon buttons sits above the chips; tapping
/// one reveals that control inline, in a small attached surface that grows the
/// card slightly rather than covering the frame with a large panel. Exactly one
/// section is open at a time — opening one collapses any other.
///
/// A shared meter control: both orientations compose the *same* strip inside the
/// shared `MeterHUDCard`, so its icon buttons and the tour anchors on the
/// controls it reveals survive rotation without re-wiring.
///
/// The open/collapsed state is *view-local* (`@State`), never `MeterViewModel`
/// state. During the guided tour the strip force-opens whichever section the
/// current step targets (`tourStep`), so the `.compensation` and
/// `.meteringPattern` tour anchors — which live inside the revealed controls —
/// resolve even though those controls are hidden in ordinary use.
///
/// Under Reduce Motion the reveal is a plain swap: the height/position animation
/// is dropped so nothing slides.
struct MeterControlStrip: View {
    let model: MeterViewModel
    /// The guided tour's current step, or `nil` when the tour isn't running.
    /// While a step that lives in the strip is active, its section is forced
    /// open so the spotlight anchor resolves.
    var tourStep: GuidedTourStep?

    /// Which occasional control the strip exposes — also the reveal identity and
    /// the single-open-at-a-time selector.
    enum Section: Hashable {
        case compensation
        case pattern
    }

    /// The strip section the guided tour force-opens for `step`, or `nil` for
    /// steps whose control stays in the persistent layout (or when no tour runs).
    /// Pure and exhaustive so a new step can't silently fall through. The priority
    /// step (`.priorityAndChips`) forces nothing open now — its control is the
    /// persistent chips, whose anchor resolves without revealing anything.
    static func tourSection(for step: GuidedTourStep?) -> Section? {
        switch step {
        case .meteringPattern: .pattern
        case .compensation: .compensation
        case .welcome, .evReadout, .priorityAndChips, .dial, .settings, .none: nil
        }
    }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var openSection: Section?

    /// The section actually shown: the tour override wins while the tour drives a
    /// strip step; otherwise the photographer's own open section (untouched by
    /// the tour, keeping strip state purely view-local).
    private var effectiveOpen: Section? {
        Self.tourSection(for: tourStep) ?? openSection
    }

    var body: some View {
        VStack(spacing: 10) {
            iconRow
            if let section = effectiveOpen {
                revealed(section)
                    // Slide-and-fade in the non-reduced path; the reveal
                    // animation below is nil'd out under Reduce Motion, which
                    // turns this into a plain, instantaneous swap.
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(reduceMotion ? nil : .snappy, value: effectiveOpen)
    }

    private var iconRow: some View {
        HStack(spacing: 10) {
            iconButton(
                .compensation,
                systemImage: "plusminus",
                label: "Exposure compensation",
                value: model.compensationLabel
            )
            iconButton(
                .pattern,
                systemImage: model.pattern.systemImage,
                label: "Metering pattern",
                value: model.pattern.label
            )
        }
    }

    private func iconButton(
        _ section: Section,
        systemImage: String,
        label: String,
        value: String
    ) -> some View {
        let isOpen = effectiveOpen == section
        return Button {
            toggle(section)
        } label: {
            // Glyph + current value fills the pill deliberately, so each button
            // carries its state at a glance instead of floating a lone icon in a
            // wide, empty capsule.
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                Text(value)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .font(.footnote.weight(.semibold))
            .foregroundStyle(isOpen ? AnyShapeStyle(.tint) : AnyShapeStyle(.white))
            .frame(maxWidth: .infinity, minHeight: 44)
            // Make the whole pill tappable. `glassEffect` (unlike `background`)
            // doesn't contribute a hit region, so without this only the glyph +
            // value are hittable and taps on the empty pill fall through — the
            // same explicit content shape the settings gear and the segmented
            // toggles already carry.
            .contentShape(Capsule())
            .modifier(GlassPillBackground(isActive: isOpen))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityValue(value)
        .accessibilityAddTraits(isOpen ? .isSelected : [])
        .accessibilityHint(isOpen ? "Hides the control" : "Shows the control")
    }

    /// Toggles a section open, collapsing any other — enforcing one-open-at-a-time
    /// purely in view-local state.
    private func toggle(_ section: Section) {
        openSection = (openSection == section) ? nil : section
    }

    @ViewBuilder private func revealed(_ section: Section) -> some View {
        switch section {
        case .compensation:
            CompensationControl(
                value: model.compensationLabel,
                isBound: model.isCompensationDialBound,
                onSelect: model.bindCompensationDial
            )
            .guidedTourAnchor(.compensation)
        case .pattern:
            MeteringPatternToggle(
                pattern: model.pattern,
                onSelect: { model.setPattern($0) }
            )
            .guidedTourAnchor(.meteringPattern)
        }
    }
}
