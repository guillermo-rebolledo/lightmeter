import SwiftUI

/// The landscape (`verticalSizeClass == .compact`) arrangement of the metering
/// HUD, spread to the screen's edges around the camera-preview hero:
///
/// - **Leading edge:** a single `.ultraThinMaterial` control column — the
///   freeze/compensation row, metering-pattern toggle, and priority+chips group
///   stacked vertically (each row stays horizontal internally), with the
///   advisories anchored at the column's bottom.
/// - **Middle:** the preview shows through; the EV@ISO100 readout floats at its
///   top-leading corner as the hero reference.
/// - **Trailing edge:** the vertical ruler dial, hugging the trailing side.
///
/// Composes the *same* shared control views as `PortraitMeterLayout` — each
/// carries its own tour anchor — so rotating between layouts never tears down
/// the camera or re-wires the guided tour. Safe-area insets keep the column and
/// dial clear of the notch and home indicator; because the column sits on the
/// leading edge and the dial on the trailing edge, the layout is identical for
/// `.landscapeLeft` and `.landscapeRight` (no per-rotation mirroring).
struct LandscapeMeterLayout: View {
    let model: MeterViewModel
    /// The advisories snapshot to display — frozen while the tour runs.
    let advisories: [ExposureAdvisory]
    let isTourActive: Bool

    /// The leading control column's total panel width (including its material
    /// padding), sized within the ~240–280pt band to hold the horizontal rows
    /// comfortably without crowding the preview hero.
    private let columnWidth: CGFloat = 260

    var body: some View {
        HStack(spacing: 0) {
            controlColumn

            // The preview hero shows through this middle region; the EV readout
            // floats at its top-leading corner.
            EVReadoutView(ev: model.ev)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(.leading, 20)
                .padding(.top, 4)

            MeterDialHost(model: model, axis: .vertical)
        }
    }

    private var controlColumn: some View {
        VStack(spacing: 16) {
            FreezeCompensationRow(model: model)
            MeteringPatternRow(model: model)
            PriorityAndChipsGroup(model: model)
            // Advisories anchored at the column bottom, still height-frozen
            // during the tour so live warnings can't shove spotlight targets.
            Spacer(minLength: 12)
            MeterAdvisories(advisories: advisories, isTourActive: isTourActive)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(20)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        // Constrain the whole panel (content + material padding) to the band,
        // rather than the inner content — so the rendered card stays ~260pt.
        .frame(width: columnWidth)
        .padding(.leading, 16)
        .padding(.vertical, 16)
    }
}
