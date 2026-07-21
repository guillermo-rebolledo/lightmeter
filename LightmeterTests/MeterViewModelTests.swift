import Testing
import Foundation
@testable import Lightmeter

/// `MeterViewModel` driven by a fake `LightSource` — no camera involved.
@MainActor
struct MeterViewModelTests {
    /// Waits for `predicate` to hold, yielding to let the metering task run.
    /// Fails fast rather than hanging if the state never settles.
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

    @Test func startBeginsMeteringWhenAuthorized() async {
        let source = FakeLightSource()
        let vm = MeterViewModel(source: source)

        await vm.start()

        #expect(vm.status == .metering)
        #expect(source.didStart)
        #expect(vm.ev == nil)
    }

    @Test func latestEVTracksIncomingReadings() async {
        let source = FakeLightSource()
        let vm = MeterViewModel(source: source)
        await vm.start()

        // Sunny 16 → EV 15.
        source.emit(LightReading(iso: 100, exposureDuration: 1.0 / 128.0, aperture: 16))
        await waitUntil { vm.ev != nil }
        #expect(abs((vm.ev ?? .nan) - 15) < 0.001)

        // A much dimmer scene → the readout follows it down live.
        let dim = LightReading(iso: 100, exposureDuration: 1.0, aperture: 1)
        source.emit(dim)
        await waitUntil { abs((vm.ev ?? .infinity) - 0) < 0.001 }
        #expect(vm.latestReading == dim)
    }

    @Test func resumesMeteringAfterStopAndRestart() async {
        let source = FakeLightSource()
        let vm = MeterViewModel(source: source)

        await vm.start()
        source.emit(LightReading(iso: 100, exposureDuration: 1.0 / 128.0, aperture: 16))
        await waitUntil { vm.ev != nil }

        vm.stop()
        #expect(vm.status == .idle)

        // Restarting must resume live readings — each start() gets a fresh stream.
        await vm.start()
        #expect(vm.status == .metering)

        let dim = LightReading(iso: 100, exposureDuration: 1.0, aperture: 1)
        source.emit(dim)
        await waitUntil { abs((vm.ev ?? .infinity) - 0) < 0.001 }
        #expect(vm.latestReading == dim)
    }

    @Test func statusResetsToIdleWhenStreamFinishesWithoutStop() async {
        let source = FakeLightSource()
        let vm = MeterViewModel(source: source)
        await vm.start()
        #expect(vm.status == .metering)

        // The source's capture ends on its own (e.g. no camera available).
        source.finishStream()

        await waitUntil { vm.status == .idle }
        #expect(vm.status == .idle)
    }

    @Test func deniedAuthorizationShowsDeniedState() async {
        let source = FakeLightSource()
        source.authorization = .denied
        let vm = MeterViewModel(source: source)

        await vm.start()

        #expect(vm.status == .denied)
        #expect(!source.didStart)
        #expect(vm.ev == nil)
    }

    @Test func stopEndsMeteringAndReturnsToIdle() async {
        let source = FakeLightSource()
        let vm = MeterViewModel(source: source)
        await vm.start()

        vm.stop()

        #expect(source.didStop)
        #expect(vm.status == .idle)
    }

    // MARK: - Exposure triangle

    /// Before any reading the two set legs show, the shutter is pending, and the
    /// shutter is flagged as the solved (non-editable) leg.
    @Test func triangleShowsSetLegsWithPendingShutterBeforeMetering() {
        let vm = MeterViewModel(source: FakeLightSource())

        let triangle = vm.triangle
        #expect(triangle.iso.label == "100")
        #expect(triangle.aperture.label == "8")
        #expect(triangle.shutter == nil)
        #expect(triangle.solved == .shutter)
        #expect(triangle.isSolved(.shutter))
    }

    /// Metering a scene solves the shutter live and snaps it to a dial mark.
    /// Sunny 16 at ISO 100, f/16 solves to 1/125.
    @Test func triangleSolvesShutterLiveFromReadings() async {
        let source = FakeLightSource()
        let vm = MeterViewModel(source: source)
        vm.setAperture(16)
        await vm.start()

        source.emit(LightReading(iso: 100, exposureDuration: 1.0 / 128.0, aperture: 16))
        await waitUntil { vm.triangle.shutter != nil }

        #expect(vm.triangle.shutter?.label == "1/125")
        #expect(vm.triangle.isSolved(.shutter))
    }

    /// The solved shutter tracks the light: a dimmer scene yields a slower
    /// (longer) shutter — the ticket's demo behavior.
    @Test func solvedShutterTracksTheLight() async {
        let source = FakeLightSource()
        let vm = MeterViewModel(source: source)
        vm.setAperture(8)
        await vm.start()

        // Bright scene (Sunny 16, EV 15).
        source.emit(LightReading(iso: 100, exposureDuration: 1.0 / 128.0, aperture: 16))
        await waitUntil { vm.triangle.shutter != nil }
        let bright = vm.triangle.shutter!.value

        // A much dimmer scene (EV 0): shutter opens up to a longer duration.
        source.emit(LightReading(iso: 100, exposureDuration: 1.0, aperture: 1))
        await waitUntil { (vm.triangle.shutter?.value ?? bright) > bright }
        #expect(vm.triangle.shutter!.value > bright)
    }

    /// The aperture is a live input: changing it re-solves the shutter from the
    /// same scene light (fixed aperture, solved shutter — aperture-priority).
    @Test func changingApertureResolvesShutter() async {
        let source = FakeLightSource()
        let vm = MeterViewModel(source: source)
        vm.setAperture(16)
        await vm.start()

        source.emit(LightReading(iso: 100, exposureDuration: 1.0 / 128.0, aperture: 16))
        await waitUntil { vm.triangle.shutter != nil }
        let atF16 = vm.triangle.shutter!.value

        // Opening two stops to f/8 lets in 4× the light → shutter 4× faster.
        vm.setAperture(8)
        #expect(vm.triangle.aperture.label == "8")
        #expect(abs(atF16 / vm.triangle.shutter!.value - 4) < 0.01)
    }

    /// ISO is a live input too: raising it one stop re-solves to a shutter one
    /// stop faster (half the duration) from the same scene light.
    @Test func changingISOResolvesShutter() async {
        let source = FakeLightSource()
        let vm = MeterViewModel(source: source)
        vm.setISO(100)
        await vm.start()

        source.emit(LightReading(iso: 100, exposureDuration: 1.0 / 128.0, aperture: 16))
        await waitUntil { vm.triangle.shutter != nil }
        let atISO100 = vm.triangle.shutter!.value

        vm.setISO(200)
        #expect(vm.triangle.iso.label == "200")
        #expect(abs(atISO100 / vm.triangle.shutter!.value - 2) < 0.01)
    }
}
