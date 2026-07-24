#if DEBUG
import CoreGraphics
import Foundation

/// A `LightSource` that stands in for the camera at a fixed scene brightness.
///
/// It fabricates the same shape of data the camera streams — an ISO / duration /
/// aperture triple — chosen so that `ExposureEngine`'s *real* conversion turns it
/// back into the requested `sceneEV`. Nothing downstream is special-cased for the
/// harness: the view-model and the engine run exactly the code they run on a
/// phone, which is the whole point of the trust gate.
///
/// Readings repeat on a slow cadence rather than being emitted once. The camera
/// streams for as long as the screen is up, and `MeterViewModel` leaves
/// `.metering` when its stream finishes — a one-shot source would quietly change
/// the state the screen is screenshotted in.
///
/// `LightSource` is deliberately not `@MainActor` (the real camera works on its
/// own queues), so this one's mutable state is guarded by a lock, the same way
/// `CameraLightSource`'s sampler guards the continuation it swaps between
/// sessions. Today's only caller is the main-actor view-model, but the protocol
/// does not promise that.
final class ScriptedLightSource: LightSource {
    /// The scene's EV@ISO 100 — what the meter will read.
    let sceneEV: Double

    /// Whether readings are actually published. A source that authorizes, starts,
    /// and then stays silent is how the harness reaches the state *before the
    /// first reading* — the meter is genuinely metering and genuinely has nothing
    /// yet, exactly as it is for the first moment on a phone. The stream stays
    /// open, because a stream that ended would mean capture had failed.
    let emitsReadings: Bool

    /// How often a reading is republished. Slow enough to cost nothing, frequent
    /// enough that the screen is genuinely live under the harness.
    private static let emitInterval = Duration.milliseconds(250)

    /// The legs held fixed while the duration carries the scene's light: ISO 100
    /// needs no normalization, and f/8 keeps the solved duration in a plausible
    /// range across the whole EV span the meter covers.
    private static let fixedISO: Double = 100
    private static let fixedAperture: Double = 8

    private let lock = NSLock()
    private var emitTask: Task<Void, Never>?
    private var activeContinuation: AsyncStream<LightReading>.Continuation?
    private var routedExposurePoint: CGPoint?

    init(sceneEV: Double, emitsReadings: Bool = true) {
        self.sceneEV = sceneEV
        self.emitsReadings = emitsReadings
    }

    deinit {
        emitTask?.cancel()
        activeContinuation?.finish()
    }

    /// The last exposure point of interest the view-model routed, so spot
    /// metering stays drivable under the harness even with nothing to aim.
    /// `nil` is whole-frame average.
    var exposurePointOfInterest: CGPoint? {
        lock.withLock { routedExposurePoint }
    }

    /// The sample this source publishes: the fixed ISO and aperture, with the
    /// exposure duration solved so the triple measures back as `sceneEV`.
    ///
    /// Solved through `ExposureEngine` rather than by an inlined formula, so the
    /// harness cannot drift away from the conversion it is standing in for.
    var reading: LightReading {
        LightReading(
            iso: Self.fixedISO,
            exposureDuration: ExposureEngine.shutterDuration(
                evAtISO100: sceneEV,
                iso: Self.fixedISO,
                aperture: Self.fixedAperture
            ),
            aperture: Self.fixedAperture
        )
    }

    func requestAuthorization() async -> LightSourceAuthorization {
        // No AVFoundation involved, so nothing to ask for — and no permission
        // alert to dismiss before a screenshot can be taken.
        .authorized
    }

    func start() -> AsyncStream<LightReading> {
        let (stream, continuation) = AsyncStream<LightReading>.makeStream(
            bufferingPolicy: .bufferingNewest(1)
        )
        let reading = self.reading
        let emitsReadings = self.emitsReadings

        // Detached so the emit loop doesn't inherit the caller's actor: the
        // camera samples on its own queues, and the stand-in should not quietly
        // hop the main actor every tick. The stream is finished by whoever ends
        // the session — `stop()` or `deinit` — never by this loop, so a
        // cancellation can't look to the view-model like capture died.
        let task = Task.detached {
            // Yield the first reading immediately so the meter is live on the
            // first frame — a screenshot taken right after launch is a screenshot
            // of the metering screen, not of the pre-first-reading state. Unless
            // the pre-first-reading state is what was asked for, in which case
            // this loop simply never yields and the stream stays open.
            guard emitsReadings else { return }
            continuation.yield(reading)
            while Task.isCancelled == false {
                try? await Task.sleep(for: Self.emitInterval)
                guard Task.isCancelled == false else { break }
                continuation.yield(reading)
            }
        }

        // Defensive, mirroring the camera: a start() without a matching stop()
        // finishes the prior session's stream rather than leaving its consumer
        // hanging.
        endSession(replacingWith: (task, continuation))

        return stream
    }

    func stop() {
        endSession(replacingWith: nil)
    }

    /// Cancels the current emit loop and finishes its stream, optionally
    /// installing `next` as the new session in the same locked step.
    ///
    /// The stream is finished here rather than inside the emit task because the
    /// protocol says `stop()` finishes the stream returned by the matching
    /// `start()` — waiting for a cancelled task to notice would let one more
    /// queued reading land after the caller believes metering has ended.
    private func endSession(
        replacingWith next: (Task<Void, Never>, AsyncStream<LightReading>.Continuation)?
    ) {
        let previous = lock.withLock {
            let previous = (task: emitTask, continuation: activeContinuation)
            emitTask = next?.0
            activeContinuation = next?.1
            return previous
        }
        previous.task?.cancel()
        previous.continuation?.finish()
    }

    func setExposurePointOfInterest(_ point: CGPoint?) {
        lock.withLock { routedExposurePoint = point }
    }
}
#endif
