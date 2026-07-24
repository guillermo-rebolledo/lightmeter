import SwiftUI

/// The compact, always-glanceable compensation readout that lives in the dial
/// panel where the permanent slider used to be — the single trigger for driving
/// exposure bias on the one shared ruler.
///
/// Direction 1b polish removes the permanent compensation slider: a full-width
/// band was occupying the instrument even at zero bias, competing with the ruler
/// for space the photographer rarely needs. In its place, compensation becomes an
/// *on-demand* dial. This readout is how it is summoned and dismissed:
///
/// - **It shows the live bias** and is **always present, even at zero** — it is the
///   only way in, so it cannot hide when there is no bias yet to report; it is also
///   how the photographer confirms they *have* dialled some in.
/// - **Tapping it takes over the shared ruler** (``MeterViewModel/bindCompensationDial()``),
///   pointing the one dial at the compensation scale. It reuses the model's existing
///   `DialTarget.compensation` path wholesale — no new mechanics.
/// - **It is tinted and ringed while active**, mirroring the ISO affordance, so a
///   glance says the ruler is currently driving compensation rather than a leg.
/// - **It is the way home too:** tapping again, while the ruler is already on
///   compensation, dismisses the overlay and returns the dial to the priority leg —
///   the same toggle — so the readout is both the way in and the way out. (Tapping
///   any aperture / shutter / ISO cell in the mode row brings the ruler home as
///   well, so the photographer is never stranded in compensation.)
///
/// It is deliberately *not* a sixth cell in the mode row (that would break the
/// row's 3 + 2 reading) and *not* in the top bar (comp belongs next to the dial it
/// now drives). It is shorter than the 44pt slider band it replaces, so the panel
/// it sits in stays fixed-height by construction.
struct CompensationReadout: View {
    /// The signed bias as shown — ``MeterViewModel/compensationLabel`` (`"+0.3 EV"`,
    /// `"0.0 EV"`). Present whatever the value, zero included.
    let label: String
    /// Whether the shared ruler is currently bound to compensation —
    /// ``MeterViewModel/isCompensationDialBound``. Drives the tint and ring.
    let isActive: Bool
    /// Summons or dismisses the comp dial — routes to
    /// ``MeterViewModel/bindCompensationDial()``, so the model's behaviour is untouched.
    let onTap: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// The spoken name and hint — pinned as constants so what the readout says is
    /// testable without walking the accessibility tree, the same shape as the ISO
    /// control's hint it mirrors.
    static let accessibilityLabel = "Exposure compensation"
    static let accessibilityHint = "Points the dial at the compensation scale"

    /// The ring when the dial is pointed elsewhere: brighter than the panel's own
    /// hairline rim, because this one has to say *tappable* rather than merely find
    /// an edge — the same value the ISO control wore.
    private static let outlineOpacity = 0.28

    var body: some View {
        Button(action: onTap) { pill }
            .buttonStyle(.plain)
            // The value springs (a value the photographer *moves*) so the count-up
            // runs, collapsing to a snap under Reduce Motion — matching the numeral.
            .animation(reduceMotion ? nil : .snappy, value: label)
            .accessibilityLabel(Self.accessibilityLabel)
            .accessibilityValue(label)
            .accessibilityHint(Self.accessibilityHint)
            // The tint and ring are silent, so the active state has to be spoken.
            .accessibilityAddTraits(isActive ? .isSelected : [])
    }

    /// The pill itself: a caption and the signed value, tinted and ringed while the
    /// ruler is bound to compensation.
    private var pill: some View {
        HStack(spacing: 8) {
            Text("Exposure comp")
                // The instrument's caption face, matching the dial panel's own
                // caption above it.
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(1.5)

            Text(label)
                // Counts as it steps under the thumb, like every other numeric
                // readout on the screen; accent while active, matching the ring.
                .font(AppTypography.numeral(.caption, weight: .semibold))
                .foregroundStyle(valueStyle)
                .contentTransition(.numericText())
        }
        // One scale-to-fit line so a widening value ("+3.0 EV") never grows the
        // panel's height.
        .scaledToFitOnOneLine(minimumScale: 0.7)
        .padding(.horizontal, 12)
        .frame(minHeight: Self.targetHeight)
        // The glass surface contributes no hit region, so pin the tappable area to
        // the whole pill.
        .contentShape(Capsule())
        .background(activeFill)
        // Accent while the ruler is on compensation, hairline otherwise — a stroke
        // inside the pill's own bounds, so toggling costs no layout.
        .overlay(Capsule().strokeBorder(ringStyle, lineWidth: 1))
    }

    /// The value colour — accent while driving compensation, white otherwise.
    private var valueStyle: AnyShapeStyle {
        isActive ? AnyShapeStyle(.tint) : AnyShapeStyle(.white)
    }

    /// The active fill in the app's highlight vocabulary — the low-opacity accent
    /// the selected mode cell and the old ISO control wear — or nothing at rest.
    @ViewBuilder private var activeFill: some View {
        if isActive {
            Capsule().fill(.tint.opacity(0.22))
        }
    }

    /// The ring: accent while active, hairline otherwise.
    private var ringStyle: AnyShapeStyle {
        isActive ? AnyShapeStyle(.tint) : AnyShapeStyle(.white.opacity(Self.outlineOpacity))
    }

    /// The pill's height — smaller than the panel's 44pt chrome, a value that
    /// happens to be tappable rather than a piece of chrome, but tall enough that
    /// the ring is a target and not a decoration. Shorter than the 44pt slider band
    /// it replaces, which is what keeps the panel from growing.
    private static let targetHeight: CGFloat = 34
}

#Preview {
    struct Harness: View {
        @State private var active = false
        var body: some View {
            ZStack {
                LinearGradient(colors: [.white, .cyan], startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()
                VStack(spacing: 24) {
                    CompensationReadout(label: "0.0 EV", isActive: active, onTap: { active.toggle() })
                    CompensationReadout(label: "+0.3 EV", isActive: true, onTap: {})
                    CompensationReadout(label: "-1.7 EV", isActive: false, onTap: {})
                }
                .padding()
            }
            .tint(.appAccent)
            .preferredColorScheme(.dark)
        }
    }
    return Harness()
}
