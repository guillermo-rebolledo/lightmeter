import Foundation

/// Which leg of the exposure triangle a solve computed, as opposed to the two
/// the photographer set. `.shutter` in aperture-priority (v1 default); `.aperture`
/// once shutter-priority (#5) lands.
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

    /// The photographic scale this leg dials along — the detents the arc dial
    /// lays out for it.
    var scale: PhotographicScale {
        switch self {
        case .iso: return .iso
        case .aperture: return .aperture
        case .shutter: return .shutter
        }
    }
}
