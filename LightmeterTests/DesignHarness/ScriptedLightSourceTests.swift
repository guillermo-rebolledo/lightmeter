import Testing
import CoreGraphics
@testable import Lightmeter

/// The harness' stand-in for the camera.
///
/// The harness is only trustworthy if the EV on screen is the EV that was asked
/// for on the command line — a screenshot taken at "EV 15" has to be a screenshot
/// of the meter reading 15. The source therefore has to round-trip through the
/// *real* `ExposureEngine` conversion the camera's samples go through, which is
/// what these tests pin.
@MainActor
struct ScriptedLightSourceTests {
    /// Waits for `predicate` to hold, yielding to let the metering task run.
    /// Fails as "never became true" rather than as a confusing downstream `nil`.
    private func waitUntil(
        _ predicate: () -> Bool,
        sourceLocation: SourceLocation = #_sourceLocation
    ) async {
        for _ in 0..<10_000 {
            if predicate() { return }
            await Task.yield()
        }
        Issue.record("Condition never became true", sourceLocation: sourceLocation)
    }

    @Test func authorizesWithoutTouchingTheCamera() async {
        let source = ScriptedLightSource(sceneEV: 15)

        #expect(await source.requestAuthorization() == .authorized)
    }

    @Test func emittedReadingsConvertBackToTheRequestedSceneEV() async {
        for sceneEV in [-2.0, 0, 6.5, 12, 15, 19.7] {
            let source = ScriptedLightSource(sceneEV: sceneEV)

            let reading = source.reading
            let measured = ExposureEngine.evAtISO100(for: reading)

            #expect(measured != nil)
            #expect(abs((measured ?? .nan) - sceneEV) < 0.0001)
        }
    }

    /// Whatever the requested light, the reading has to be one the engine accepts
    /// — a non-finite or non-positive leg is dropped at the camera boundary and
    /// the meter would sit on `.unavailable` forever.
    @Test func emittedReadingsAreAlwaysPhysicallyValid() {
        for sceneEV in stride(from: -5.0, through: 20.0, by: 0.5) {
            let reading = ScriptedLightSource(sceneEV: sceneEV).reading

            #expect(reading.iso > 0 && reading.iso.isFinite)
            #expect(reading.aperture > 0 && reading.aperture.isFinite)
            #expect(reading.exposureDuration > 0 && reading.exposureDuration.isFinite)
        }
    }

    @Test func drivesTheMeterToTheRequestedSceneEV() async {
        let source = ScriptedLightSource(sceneEV: 12.5)
        let model = MeterViewModel(source: source)

        await model.start()
        await waitUntil { model.ev != nil }

        #expect(model.status == .metering)
        #expect(abs((model.ev ?? .nan) - 12.5) < 0.0001)

        model.stop()
    }

    /// The camera keeps streaming for as long as the screen is up; so must the
    /// stand-in, or the meter would drop out of `.metering` mid-session and the
    /// harness would stop reproducing the screen it exists to reproduce.
    @Test func keepsStreamingUntilStopped() async {
        let source = ScriptedLightSource(sceneEV: 15)
        let model = MeterViewModel(source: source)

        await model.start()
        await waitUntil { model.ev != nil }
        for _ in 0..<200 { await Task.yield() }

        #expect(model.status == .metering)

        model.stop()
    }

    /// The protocol says `stop()` finishes the stream returned by the matching
    /// `start()`. The view-model relies on that to leave `.metering` cleanly
    /// rather than on a cancelled loop noticing at its own pace.
    @Test func stopFinishesTheStream() async {
        let source = ScriptedLightSource(sceneEV: 15)
        let stream = source.start()

        var received = 0
        source.stop()
        for await _ in stream {
            received += 1
        }

        // The loop above only exits because the stream finished; the count is
        // whatever the first immediate yield left buffered.
        #expect(received <= 1)
    }

    /// Spot metering has to remain drivable under the harness even though there
    /// is no capture device to aim — the point is recorded, not dropped.
    @Test func recordsTheExposurePointOfInterest() {
        let source = ScriptedLightSource(sceneEV: 15)

        source.setExposurePointOfInterest(CGPoint(x: 0.25, y: 0.75))

        #expect(source.exposurePointOfInterest == CGPoint(x: 0.25, y: 0.75))
    }
}
