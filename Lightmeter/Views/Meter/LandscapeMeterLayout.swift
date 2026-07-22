import SwiftUI

/// The landscape (`verticalSizeClass == .compact`) arrangement of the metering
/// HUD, spread to the screen's edges around the camera-preview hero:
///
/// - **Leading edge:** the shared `MeterHUDCard` as a fixed-width column — the
///   same compact, thinner, more-transparent card portrait hugs to the bottom,
///   here pinned to the top-leading corner. It carries the demoted freeze icon,
///   smaller readout, thin advisory line, inline expanding control strip, and
///   the chips.
/// - **Middle:** the preview shows through.
/// - **Trailing edge:** the vertical ruler dial, hugging the trailing side.
///
/// Composing the *same* `MeterHUDCard` as `PortraitMeterLayout` — each control
/// carrying its own tour anchor — is what brings landscape to parity and keeps
/// rotation from tearing down the camera or re-wiring the guided tour. Because
/// the column sits on the leading edge and the dial on the trailing edge, the
/// layout is identical for `.landscapeLeft` and `.landscapeRight` (no
/// per-rotation mirroring); the dial folds into the card in portrait instead, so
/// the card here passes `foldsInDial: false`.
struct LandscapeMeterLayout: View {
    let model: MeterViewModel
    /// The advisories snapshot to display — frozen while the tour runs.
    let advisories: [ExposureAdvisory]
    let isTourActive: Bool
    /// The guided tour's current step, forwarded to the shared card's control
    /// strip so it can force-open the section the active step targets.
    var tourStep: GuidedTourStep?

    /// The leading card column's fixed width, sized to hold the folded-in
    /// controls comfortably without crowding the preview hero.
    private let columnWidth: CGFloat = 260

    var body: some View {
        HStack(spacing: 0) {
            // Scroll only when the card can't fit: `.basedOnSize` keeps it
            // pinned to the top at its natural height (mirroring how portrait
            // hugs the bottom edge) and starts scrolling only when a short
            // landscape height or large Dynamic Type sizes would otherwise clip
            // the chips — and with them the `.priorityAndChips` tour anchor.
            ScrollView(.vertical) {
                MeterHUDCard(
                    model: model,
                    advisories: advisories,
                    isTourActive: isTourActive,
                    tourStep: tourStep,
                    foldsInDial: false
                )
                .frame(width: columnWidth)
                .padding(.leading, 16)
                .padding(.vertical, 16)
            }
            .scrollBounceBehavior(.basedOnSize)
            .scrollIndicators(.hidden)
            // Constrain the scroll region to the card's footprint so the middle
            // stays clear preview; the width folds in the leading inset.
            .frame(width: columnWidth + 16)

            // The preview hero shows through this middle region.
            Spacer(minLength: 0)

            MeterDialHost(model: model, axis: .vertical)
        }
    }
}
