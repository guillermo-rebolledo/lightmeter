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
        for _ in 0..<10_000 where model.ev == nil {
            await Task.yield()
        }

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
        for _ in 0..<10_000 where model.ev == nil {
            await Task.yield()
        }
        for _ in 0..<200 { await Task.yield() }

        #expect(model.status == .metering)

        model.stop()
    }

    /// Spot metering has to remain drivable under the harness even though there
    /// is no capture device to aim — the point is recorded, not dropped.
    @Test func recordsTheExposurePointOfInterest() {
        let source = ScriptedLightSource(sceneEV: 15)

        source.setExposurePointOfInterest(CGPoint(x: 0.25, y: 0.75))

        #expect(source.exposurePointOfInterest == CGPoint(x: 0.25, y: 0.75))
    }
}
