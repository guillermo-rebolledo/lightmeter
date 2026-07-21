import CoreGraphics
import Foundation

extension CGPoint {
    /// The center of the normalized `[0, 1] × [0, 1]` device frame — where
    /// exposure metering falls back to for a center-weighted average read (no
    /// spot placed). The single source of truth shared by the view-model, the
    /// camera adapter, and the preview reticle.
    static let frameCenter = CGPoint(x: 0.5, y: 0.5)
}

/// How the frame is metered: a whole-frame center-weighted average, or a spot
/// placed on a specific tone. Spot points the camera's auto-exposure region of
/// interest at the tapped point; average lets the whole frame drive the read.
enum MeteringPattern: CaseIterable, Equatable, Sendable {
    /// Center-weighted whole-frame metering — the balanced default.
    case average
    /// Tap-to-place spot metering biased to a single point.
    case spot

    /// The pattern's short display label.
    var label: String {
        switch self {
        case .average: return "Average"
        case .spot: return "Spot"
        }
    }

    /// The SF Symbol that depicts this metering pattern.
    var systemImage: String {
        switch self {
        case .average: return "camera.metering.center.weighted"
        case .spot: return "camera.metering.spot"
        }
    }

    /// The other pattern — what a single toggle switches to.
    var toggled: MeteringPattern {
        switch self {
        case .average: return .spot
        case .spot: return .average
        }
    }
}
