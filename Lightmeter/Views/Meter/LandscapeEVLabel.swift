import SwiftUI

/// Landscape's EV readout: the quiet label floating over the preview, where EV
/// has always been read in this orientation.
///
/// Direction 1b promotes EV to a headline bar, but that is a **portrait** screen
/// (#91: "the variant is portrait-only"). Landscape gets no bar, so without this
/// it would have come out of #96 with no EV reading at all — the reticle badge
/// and the secondary label were both removed, and only portrait gained something
/// in their place.
///
/// So landscape keeps reading EV where it did. Two things did change, and both
/// are simplifications rather than redesigns:
///
/// - It reads the scene in **both metering patterns**, not only when averaging.
///   The spot counterpart used to be the reticle's inline badge, which is gone:
///   the reticle marks the point and reports nothing.
/// - The words come from the same ``EVHeadlineReadout`` the portrait bar renders,
///   so the two orientations cannot quote the scene differently, and the ISO 100
///   qualifier (ADR-0001) rides the spoken value here exactly as it does there.
struct LandscapeEVLabel: View {
    let readout: EVHeadlineReadout

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Text(readout.value)
            .font(AppTypography.numeral(.footnote))
            .foregroundStyle(.white)
            .contentTransition(.numericText())
            .scaledToFitOnOneLine(minimumScale: 0.7)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            // The label floats on the raw scene — a blown-out sky washes out
            // white text — so it takes the same scrim the status pills use.
            .modifier(PreviewFloatingBackground())
            .animation(reduceMotion ? nil : .snappy, value: readout.value)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(readout.accessibilityLabel)
            .accessibilityValue(readout.accessibilityValue)
    }
}

#Preview {
    ZStack {
        // Stand in for a blown-out sky: the case the label's scrim exists for.
        LinearGradient(colors: [.white, .cyan], startPoint: .top, endPoint: .bottom)
            .ignoresSafeArea()
        LandscapeEVLabel(
            readout: EVHeadlineReadout(
                ev: 12.34,
                triangle: ExposureEngine.solvedTriangle(
                    mode: .aperturePriority, evAtISO100: 12.34,
                    iso: 100, aperture: 8, shutter: 1.0 / 125
                )
            )
        )
    }
    .tint(.appAccent)
    .preferredColorScheme(.dark)
}
