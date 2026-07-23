import SwiftUI

/// The freeze control: a circular accent padlock beside the hero that holds the
/// current reading while the settings are transferred to a camera.
///
/// The padlock *is* the state. Open means the meter is live and the numbers are
/// still moving; closed means the reading is held, so the photographer can lower
/// the phone, walk to the camera, and still trust what the hero says. That is the
/// same closed padlock the held chip wears — one glyph, one meaning across the
/// variant.
///
/// Behaviour is untouched: this drives `MeterViewModel.toggleFreeze()` and mirrors
/// its guard, so nothing here changes when a reading can be held.
struct FreezeButton: View {
    let isFrozen: Bool
    let canFreeze: Bool
    let onToggle: () -> Void

    private var lock: LockState { LockState(isFrozen: isFrozen) }

    var body: some View {
        Button(action: onToggle) {
            Image(systemName: lock.symbol)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.tint)
                // The glyph swap must not move the hero it sits beside, so the
                // padlock is sized by its frame rather than by the symbol: the
                // open and closed glyphs are not the same width.
                .frame(width: Self.diameter, height: Self.diameter)
                // `glassEffect` contributes no hit region, so pin the tappable
                // area to the full circle (matching the strip buttons and gear).
                .contentShape(Circle())
                .modifier(GlassLockBackground(isHeld: isFrozen))
        }
        .buttonStyle(.plain)
        .disabled(canFreeze == false)
        .accessibilityLabel(lock.accessibilityLabel)
        .accessibilityHint(lock.accessibilityHint)
    }

    /// The circle's diameter — Apple's 44pt minimum tap target, held constant
    /// across both states so freezing is a pure repaint.
    static let diameter: CGFloat = 44
}

extension FreezeButton {
    /// What the padlock reports: the meter is either live or holding a reading.
    ///
    /// Pure over `isFrozen` so the glyph and the words VoiceOver reads in its
    /// place are testable without a view.
    enum LockState: Equatable {
        /// Live — metering. An **open** padlock: nothing is being held.
        case live
        /// Frozen — the reading is held. A **closed** padlock.
        case held

        init(isFrozen: Bool) {
            self = isFrozen ? .held : .live
        }

        var symbol: String {
            switch self {
            case .live: "lock.open.fill"
            case .held: "lock.fill"
            }
        }

        /// The padlock is silent to VoiceOver as a glyph, so the label names the
        /// action the tap performs and the hint says what that leaves you in.
        var accessibilityLabel: String {
            switch self {
            case .live: "Hold current reading"
            case .held: "Resume live metering"
            }
        }

        var accessibilityHint: String {
            switch self {
            case .live: "Locks the current exposure values so they stay steady"
            case .held: "Unlocks the reading and accepts new light"
            }
        }
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        HStack(spacing: 24) {
            FreezeButton(isFrozen: false, canFreeze: true, onToggle: {})
            FreezeButton(isFrozen: true, canFreeze: true, onToggle: {})
            // Before the first reading: nothing to hold yet.
            FreezeButton(isFrozen: false, canFreeze: false, onToggle: {})
        }
        .padding()
    }
    .tint(.appAccent)
    .preferredColorScheme(.dark)
}
