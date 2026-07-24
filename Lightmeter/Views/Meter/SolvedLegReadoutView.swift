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
                // The smallest tier in the app, and the floor the token names:
                // `.caption2` is 11pt at the default text size.
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(1.5)
                // The caption's whole job is to say which ISO the answer below is
                // the answer *for*, so a truncated "APERTURE @ ISO…" is a caption
                // that has stopped working: the longest of them
                // ("APERTURE @ ISO 12800") shrinks rather than losing its tail.
                //
                // This does not reach the *other* way that tail can go missing.
                // At `accessibility3` on the glass path the caption runs under the
                // freeze padlock and the drawer's surface clips it — the fallback
                // path, same code and same scale factor, draws it in full. That is
                // the glass container's clip, not text truncation, and it predates
                // this change; it belongs to the layout ticket.
                .scaledToFitOnOneLine(minimumScale: 0.7)

            Text(readout.value ?? ExposureTriangle.pendingMarking)
                // Sized to the decluttered card both orientations now dock; the
                // old readout's larger landscape variant had no caller left.
                // Fixed, because 34pt already outruns any Dynamic Type size.
                .font(AppTypography.numeral(fixedSize: 34))
                .foregroundStyle(.white)
                .contentTransition(.numericText())
                // Slow shutters ("1/8000", "30\"") are wider than the EV number
                // this replaced, so the hero shrinks to fit rather than wrapping
                // or truncating the answer.
                .scaledToFitOnOneLine()
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
