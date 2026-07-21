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
}
