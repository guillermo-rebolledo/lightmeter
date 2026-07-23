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
final class ScriptedLightSource: LightSource {
    /// The scene's EV@ISO 100 — what the meter will read.
    let sceneEV: Double

    /// The last exposure point of interest the view-model routed, so spot
    /// metering stays drivable under the harness even with nothing to aim.
    /// `nil` is whole-frame average.
    private(set) var exposurePointOfInterest: CGPoint?

    /// How often a reading is republished. Slow enough to cost nothing, frequent
    /// enough that the screen is genuinely live under the harness.
    private static let emitInterval = Duration.milliseconds(250)

    /// The legs held fixed while the duration carries the scene's light: ISO 100
    /// needs no normalization, and f/8 keeps the solved duration in a plausible
    /// range across the whole EV span the meter covers.
    private static let fixedISO: Double = 100
    private static let fixedAperture: Double = 8

    private var emitTask: Task<Void, Never>?

    init(sceneEV: Double) {
        self.sceneEV = sceneEV
    }

    deinit {
        emitTask?.cancel()
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

        // Defensive, mirroring the camera: a start() without a matching stop()
        // finishes the prior session's stream rather than leaving it hanging.
        emitTask?.cancel()

        let reading = self.reading
        emitTask = Task {
            // Yield the first reading immediately so the meter is live on the
            // first frame — a screenshot taken right after launch is a screenshot
            // of the metering screen, not of the pre-first-reading state.
            continuation.yield(reading)
            while Task.isCancelled == false {
                try? await Task.sleep(for: Self.emitInterval)
                guard Task.isCancelled == false else { break }
                continuation.yield(reading)
            }
            continuation.finish()
        }

        return stream
    }

    func stop() {
        emitTask?.cancel()
        emitTask = nil
    }

    func setExposurePointOfInterest(_ point: CGPoint?) {
        exposurePointOfInterest = point
    }
}
#endif
