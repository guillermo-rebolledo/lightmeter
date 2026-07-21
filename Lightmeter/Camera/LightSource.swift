import CoreGraphics
import Foundation

// MARK: - Camera / LightSource (thin, hand-validated edge)
//
// The `LightSource` protocol abstracts the source of exposure metadata so the
// view-model can be driven by a fake in tests. The production implementation
// (`CameraLightSource`) wraps AVFoundation: it requests camera permission,
// configures the capture session, runs continuous auto-exposure, streams
// ISO / exposureDuration / aperture, and aims the AE region of interest for spot
// metering.
//
// This layer is intentionally NOT unit-tested — mocking AVFoundation buys little
// and costs a lot; it is validated by hand on-device. The seam that IS tested is
// `MeterViewModel`, driven by a fake conforming to this protocol.

/// Whether the app is allowed to read the camera, mirroring the camera
/// permission lifecycle without leaking AVFoundation into the view-model.
enum LightSourceAuthorization: Sendable {
    /// The user has granted camera access.
    case authorized
    /// The user has denied or restricted camera access; the UI shows a graceful
    /// denied state rather than a live preview.
    case denied
}

/// A source of live exposure-metadata readings for the meter.
///
/// Conformers own their own lifecycle: `requestAuthorization()` triggers the
/// permission flow (a no-op returning `.authorized` for a fake) and `start()`
/// begins metering, returning a **fresh** stream of readings for that session.
/// `stop()` ends metering and finishes the stream returned by the matching
/// `start()`.
///
/// Each `start()` returns a new stream intended for a single metering session;
/// callers must not iterate it concurrently or reuse it once it has finished. A
/// stop → start cycle therefore needs a fresh stream rather than re-iterating a
/// finished one, which is why readings are vended per-`start()` instead of via one
/// shared property.
///
/// Deliberately not `@MainActor`: the real camera does its capture work on its own
/// queues. `MeterViewModel` (which *is* `@MainActor`) consumes the stream and
/// publishes UI state on the main actor.
protocol LightSource: AnyObject {
    /// Requests permission to read the camera, returning the resulting status.
    func requestAuthorization() async -> LightSourceAuthorization

    /// Begins auto-exposure metering and returns a fresh stream of readings for
    /// this session. The stream finishes when `stop()` is called.
    func start() -> AsyncStream<LightReading>

    /// Stops metering and finishes the stream returned by the matching `start()`.
    func stop()

    /// Aims the camera's auto-exposure region of interest.
    ///
    /// Pass a normalized device point in `[0, 1] × [0, 1]` (as produced by the
    /// preview layer's `captureDevicePointConverted(fromLayerPoint:)`) to bias
    /// metering toward that point for spot metering, or `nil` to reset to a
    /// center-weighted whole-frame average.
    ///
    /// Safe to call before `start()`: conformers apply the point once the capture
    /// device is configured and re-apply it for the current session.
    func setExposurePointOfInterest(_ point: CGPoint?)
}
