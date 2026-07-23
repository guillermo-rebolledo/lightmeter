import Foundation

/// Which leg of the exposure triangle the photographer holds fixed, and — by
/// consequence — which leg the engine solves. Aperture-priority (v1 default)
/// locks the aperture and solves the shutter; shutter-priority flips it, locking
/// the shutter and solving the aperture. ISO is always a set input in both.
enum PriorityMode: CaseIterable, Equatable, Sendable {
    /// Lock the aperture, solve the shutter.
    case aperturePriority
    /// Lock the shutter, solve the aperture.
    case shutterPriority

    /// The leg the engine solves in this mode — the computed, non-editable one.
    var solvedComponent: ExposureComponent {
        switch self {
        case .aperturePriority: return .shutter
        case .shutterPriority: return .aperture
        }
    }

    /// The leg the photographer holds fixed and dials in this mode — the one the
    /// mode is named for.
    var lockedComponent: ExposureComponent {
        switch self {
        case .aperturePriority: return .aperture
        case .shutterPriority: return .shutter
        }
    }

    /// The mode's short display label — the leg it prioritizes (holds fixed).
    var label: String {
        lockedComponent.caption
    }

    /// The other mode — what a single toggle switches to.
    var toggled: PriorityMode {
        switch self {
        case .aperturePriority: return .shutterPriority
        case .shutterPriority: return .aperturePriority
        }
    }

    /// The mode that locks `component` as its priority (photographer-controlled)
    /// leg, or `nil` for a leg no mode can lock — ISO, which is always an input.
    /// Tapping an AUTO chip claims this mode so the tapped leg becomes editable.
    static func locking(_ component: ExposureComponent) -> PriorityMode? {
        allCases.first { $0.lockedComponent == component }
    }
}
