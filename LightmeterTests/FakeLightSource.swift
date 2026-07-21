import CoreGraphics
import Foundation
@testable import Lightmeter

/// A hand-driven `LightSource` for testing `MeterViewModel` without a camera.
///
/// Tests set `authorization`, call the view-model, then `emit(_:)` readings and
/// observe the published EV. `start()`/`stop()` are recorded so the view-model's
/// lifecycle handling can be asserted.
final class FakeLightSource: LightSource {
    /// The result `requestAuthorization()` will return.
    var authorization: LightSourceAuthorization = .authorized

    private(set) var didStart = false
    private(set) var didStop = false

    /// Every exposure point of interest the view-model has routed, in order. A
    /// `nil` entry is average (center-weighted whole frame); a non-`nil` entry is
    /// a spot at that normalized device point.
    private(set) var exposurePoints: [CGPoint?] = []

    /// How many times an exposure point was routed — distinguishes "reset to
    /// average" (a routed `nil`) from "never routed" (empty).
    var exposurePointCallCount: Int { exposurePoints.count }

    /// The most recently routed exposure point (flattened): `nil` means the last
    /// route was average, or that nothing has been routed yet.
    var lastExposurePoint: CGPoint? { exposurePoints.last ?? nil }

    private var continuation: AsyncStream<LightReading>.Continuation?

    func requestAuthorization() async -> LightSourceAuthorization {
        authorization
    }

    func start() -> AsyncStream<LightReading> {
        didStart = true
        let (stream, continuation) = AsyncStream<LightReading>.makeStream()
        self.continuation = continuation
        return stream
    }

    func stop() {
        didStop = true
        continuation?.finish()
        continuation = nil
    }

    func setExposurePointOfInterest(_ point: CGPoint?) {
        exposurePoints.append(point)
    }

    /// Pushes a reading into the current session's stream, as the real camera
    /// would per frame. No-op before `start()`.
    func emit(_ reading: LightReading) {
        continuation?.yield(reading)
    }

    /// Finishes the current stream without going through `stop()`, simulating a
    /// source whose capture ends on its own (e.g. no camera available).
    func finishStream() {
        continuation?.finish()
        continuation = nil
    }
}
