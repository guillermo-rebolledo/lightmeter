import SwiftUI

/// The meter's hero: the exposure leg the engine solved — the setting to dial
/// into the camera — over a caption naming that leg and the ISO it assumes.
///
/// Replaces the former EV@ISO100 hero. EV is a property of the scene; this is
/// the answer, so an aperture-priority shooter reads the required shutter and a
/// shutter-priority shooter reads the required aperture, from the same spot.
///
/// A shared meter control: whichever layout composes it carries the
/// `.evReadout` tour anchor, so guided-tour targeting survives orientation
/// changes without the layout re-declaring the anchor.
struct SolvedLegReadoutView: View {
    /// The solved triangle to read the hero from. Taking the triangle (rather
    /// than a pre-derived readout) keeps the derivation in one place and lets
    /// the view animate on the triangle it actually renders.
    let triangle: ExposureTriangle

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var readout: SolvedLegReadout { SolvedLegReadout(triangle: triangle) }

    var body: some View {
        VStack(spacing: 2) {
            Text(readout.caption)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(1.5)

            Text(readout.value ?? ExposureTriangle.pendingMarking)
                // Sized to the decluttered card both orientations now dock; the
                // old readout's larger landscape variant had no caller left.
                .font(.system(size: 34, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white)
                .contentTransition(.numericText())
                // Slow shutters ("1/8000", "30\"") are wider than the EV number
                // this replaced, so the hero shrinks to fit rather than wrapping
                // or truncating the answer.
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .animation(reduceMotion ? nil : .snappy, value: triangle)
        .accessibilityElement(children: .ignore)
        // The spoken strings live on the readout, so what the hero says is
        // testable without a view — the em-dash placeholder is meaningless read
        // aloud, so pending is said in words there.
        .accessibilityLabel(readout.accessibilityLabel)
        .accessibilityValue(readout.accessibilityValue)
        .guidedTourAnchor(.evReadout)
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        VStack(spacing: 32) {
            // Aperture-priority: the hero is the shutter the app solved.
            SolvedLegReadoutView(
                triangle: ExposureEngine.solvedTriangle(
                    mode: .aperturePriority, evAtISO100: 15, iso: 100, aperture: 16, shutter: 1.0 / 125
                )
            )
            // Shutter-priority: the same hero now answers with an f-number.
            SolvedLegReadoutView(
                triangle: ExposureEngine.solvedTriangle(
                    mode: .shutterPriority, evAtISO100: 15, iso: 400, aperture: 16, shutter: 1.0 / 500
                )
            )
            // Pending — before the first reading.
            SolvedLegReadoutView(
                triangle: ExposureEngine.solvedTriangle(
                    mode: .aperturePriority, evAtISO100: nil, iso: 100, aperture: 8, shutter: 1.0 / 125
                )
            )
        }
        .padding()
    }
    .tint(.appAccent)
    .preferredColorScheme(.dark)
}
