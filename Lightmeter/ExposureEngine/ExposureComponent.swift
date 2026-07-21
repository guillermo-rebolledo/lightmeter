import Foundation

/// Which leg of the exposure triangle a solve computed, as opposed to the two
/// the photographer set. `.shutter` in aperture-priority (v1 default); `.aperture`
/// once shutter-priority (#5) lands.
enum ExposureComponent: Equatable, Sendable {
    case iso
    case aperture
    case shutter
}
