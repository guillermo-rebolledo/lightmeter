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
