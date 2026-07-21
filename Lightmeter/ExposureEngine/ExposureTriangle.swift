import Foundation

// MARK: - ExposureTriangle (the solved triangle the UI shows)
//
// The three legs of exposure — ISO, aperture, shutter — with one leg marked as
// the value the engine solved for. In aperture-priority (v1 default) the user
// sets ISO and aperture and the engine solves the shutter; shutter-priority
// (#6) flips it, locking the shutter and solving the aperture. Each leg is a
// real, dial-able `Stop`, so the triangle is always settable on a camera.

/// The exposure triangle for a metered scene: three dial-able stops with the
/// solved leg flagged. ISO is always set; the solved leg (`shutter` in
/// aperture-priority, `aperture` in shutter-priority) is `nil` until the scene
/// has been metered, so exactly one of `aperture`/`shutter` may be pending.
struct ExposureTriangle: Equatable, Sendable {
    /// The ISO the photographer set (always an input).
    var iso: PhotographicScale.Stop
    /// The aperture: a set input in aperture-priority, the solved leg (`nil`
    /// before the first reading) in shutter-priority.
    var aperture: PhotographicScale.Stop?
    /// The shutter: the solved leg (`nil` before the first reading) in
    /// aperture-priority, a set input in shutter-priority.
    var shutter: PhotographicScale.Stop?
    /// Which leg the engine solved — `.shutter` in aperture-priority,
    /// `.aperture` in shutter-priority.
    var solved: ExposureComponent

    /// Whether `component` is the solved (computed, non-editable) leg.
    func isSolved(_ component: ExposureComponent) -> Bool {
        component == solved
    }
}
