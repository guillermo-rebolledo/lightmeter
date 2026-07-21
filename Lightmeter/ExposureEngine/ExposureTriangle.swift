import Foundation

// MARK: - ExposureTriangle (the solved triangle the UI shows)
//
// The three legs of exposure — ISO, aperture, shutter — with one leg marked as
// the value the engine solved for. In aperture-priority (v1 default) the user
// sets ISO and aperture and the engine solves the shutter; shutter-priority
// (#5) flips which leg is solved. Each leg is a real, dial-able `Stop`, so the
// triangle is always settable on a camera.

/// The exposure triangle for a metered scene: three dial-able stops with the
/// solved leg flagged. `shutter` is `nil` until the scene has been metered.
struct ExposureTriangle: Equatable, Sendable {
    /// The ISO the photographer set.
    var iso: PhotographicScale.Stop
    /// The aperture the photographer set (fixed input in aperture-priority).
    var aperture: PhotographicScale.Stop
    /// The solved shutter, or `nil` before the first reading.
    var shutter: PhotographicScale.Stop?
    /// Which leg the engine solved. `.shutter` in aperture-priority.
    var solved: ExposureComponent

    /// Whether `component` is the solved (computed, non-editable) leg.
    func isSolved(_ component: ExposureComponent) -> Bool {
        component == solved
    }
}
