import SwiftUI

/// The demoted scene-EV reference at the top of the settings-first portrait meter.
///
/// Direction 1b made EV the screen's hero; the settings-first pass reverses that.
/// The exposure chips are the headline now — the three values the photographer
/// actually dials into the camera — so EV drops to a quiet reference strip. It
/// still answers "how bright is the scene?" and still names the sensitivity it is
/// quoted at (ADR-0001: the `@ ISO 100` reference is visible, not inferred), with
/// the freeze padlock and the settings gear rehoused at its two ends — the homes
/// they had on the old headline bar.
///
/// Fixed height by construction: it stretches to the width its caller insets it
/// to, its two glyph ends are frames rather than symbols, and the value is one
/// scale-to-fit line. So neither freezing nor a value that grew a digit can move
/// anything under the photographer's thumb.
struct EVReferenceStrip: View {
    let model: MeterViewModel

    /// The gap between the strip's three children and the insets off its rounded
    /// ends — the EV bar's spacing, kept so the demoted strip lines up with the
    /// chips and panel below it.
    static let itemSpacing: CGFloat = 8
    static let horizontalPadding: CGFloat = 8
    static let verticalPadding: CGFloat = 8

    private var readout: EVHeadlineReadout {
        EVHeadlineReadout(ev: model.ev, triangle: model.triangle)
    }

    var body: some View {
        HStack(spacing: Self.itemSpacing) {
            FreezeButton(
                isFrozen: model.isFrozen,
                canFreeze: model.canFreeze,
                onToggle: model.toggleFreeze,
                // The panel is already the surface separating the ends from the
                // scene, so both give up the glass they wore over the preview.
                hasSurface: false
            )

            EVReferenceReadout(readout: readout)

            // Hold the two ends at the strip's edges whatever the value says.
            Spacer(minLength: 0)

            MeterSettingsGear(hasSurface: false)
        }
        .padding(.horizontal, Self.horizontalPadding)
        .padding(.vertical, Self.verticalPadding)
        .floatingPanel()
    }
}

/// The reference's words: the scene EV under a caption that keeps the ISO-100
/// qualifier (ADR-0001). Split out as its own view so the width it needs is
/// measurable — which is what lets a test hold the strip's stability rather than
/// trusting a screenshot.
struct EVReferenceReadout: View {
    let readout: EVHeadlineReadout

    /// How far the block may shrink before the caption stops carrying the
    /// qualifier.
    static let minimumScale: CGFloat = 0.6

    /// The caption naming what the number is — scene light, not a camera setting.
    /// Worded plainly so the reference below it reads as a measurement rather than
    /// a stuck ISO dial.
    static let caption = "Scene brightness"

    /// The reference the value is quoted at, kept beside the number so `EV 12.3`
    /// can never be read as "EV at whatever ISO I set" (ADR-0001).
    static let reference = "@ ISO 100"

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(Self.caption)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(1.2)
                .scaledToFitOnOneLine(minimumScale: Self.minimumScale)

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(EVHeadlineReadout.unit)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                // Demoted well under the 28pt chip hero and the 26pt dial numeral —
                // a reference, not a headline — but still tabular and count-up so a
                // changing scene reads as one figure ticking rather than a relayout.
                Text(readout.evValue)
                    .font(AppTypography.numeral(fixedSize: 18))
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())

                Text(Self.reference)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            .scaledToFitOnOneLine(minimumScale: Self.minimumScale)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(readout.accessibilityLabel)
        // Carries the spoken "… at ISO 100" (ADR-0001), so the reference the
        // caption gives sighted readers is said aloud too.
        .accessibilityValue(readout.accessibilityValue)
    }
}

#Preview {
    ZStack {
        // Stand in for a blown-out sky: the case the panel's scrim exists for.
        LinearGradient(colors: [.white, .cyan], startPoint: .top, endPoint: .bottom)
            .ignoresSafeArea()
        VStack {
            EVReferenceStrip(model: MeterViewModel(source: CameraLightSource()))
                .padding(.horizontal, PortraitMeterLayout.panelInset)
            Spacer()
        }
    }
    .tint(.appAccent)
    .preferredColorScheme(.dark)
}
