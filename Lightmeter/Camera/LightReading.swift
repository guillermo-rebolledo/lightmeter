import Foundation

/// A single auto-exposure metadata sample from a `LightSource`.
///
/// These are the three legs of the exposure triangle the camera's AE chose for
/// the current scene. `ExposureEngine` turns them into a scene EV@ISO100. This is
/// a plain value type so it can be produced by the real camera or by a fake in
/// tests without any AVFoundation dependency.
struct LightReading: Equatable, Sendable {
    /// The ISO sensitivity the camera's auto-exposure selected (e.g. 100).
    var iso: Double

    /// The exposure duration in seconds (e.g. `1.0/128`).
    var exposureDuration: Double

    /// The lens f-number `N` (e.g. 1.8).
    var aperture: Double
}
