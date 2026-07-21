import Foundation

/// Which leg of the exposure triangle a solve computed, as opposed to the two
/// the photographer set. `.shutter` in aperture-priority (the default);
/// `.aperture` in shutter-priority.
enum ExposureComponent: Equatable, Sendable {
    case iso
    case aperture
    case shutter

    /// The leg's display caption, shared by the value chips and the dial.
    var caption: String {
        switch self {
        case .iso: return "ISO"
        case .aperture: return "Aperture"
        case .shutter: return "Shutter"
        }
    }

    /// The photographic scale this leg dials along at the selected increment.
    func scale(for increment: StopIncrement) -> PhotographicScale {
        switch self {
        case .iso: return .iso(for: increment)
        case .aperture: return .aperture(for: increment)
        case .shutter: return .shutter(for: increment)
        }
    }
}
