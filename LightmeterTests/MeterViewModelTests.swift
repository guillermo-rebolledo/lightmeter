import Testing
import Foundation
import CoreGraphics
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
        #expect(triangle.aperture?.label == "8")
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
        #expect(vm.triangle.aperture?.label == "8")
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

    // MARK: - Dial binding

    /// Tapping a chip binds the dial to that leg; nothing is bound to start.
    @Test func bindingTheDialSelectsAnEditableLeg() {
        let vm = MeterViewModel(source: FakeLightSource())
        #expect(vm.boundComponent == nil)

        vm.bindDial(to: .aperture)
        #expect(vm.boundComponent == .aperture)
    }

    /// Only one leg is ever bound — binding a new leg replaces the old one.
    @Test func bindingAnotherLegReplacesTheCurrentOne() {
        let vm = MeterViewModel(source: FakeLightSource())
        vm.bindDial(to: .aperture)
        vm.bindDial(to: .iso)
        #expect(vm.boundComponent == .iso)
    }

    /// Tapping the already-bound chip toggles the dial off.
    @Test func bindingTheBoundLegAgainUnbinds() {
        let vm = MeterViewModel(source: FakeLightSource())
        vm.bindDial(to: .aperture)
        vm.bindDial(to: .aperture)
        #expect(vm.boundComponent == nil)
    }

    /// The solved (non-editable) leg can't be bound — there's nothing to dial.
    @Test func theSolvedLegCannotBeBound() {
        let vm = MeterViewModel(source: FakeLightSource())
        vm.bindDial(to: .shutter) // shutter is solved in aperture-priority
        #expect(vm.boundComponent == nil)
    }

    /// The bound stops and the current index describe the bound leg's scale and
    /// where its value sits on it (aperture f/8 is index 18 on the f-scale).
    @Test func boundStopsAndIndexTrackTheBoundLeg() {
        let vm = MeterViewModel(source: FakeLightSource())
        #expect(vm.boundStops.isEmpty)
        #expect(vm.boundStopIndex == nil)

        vm.bindDial(to: .aperture)
        #expect(vm.boundStops == PhotographicScale.aperture.stops)
        #expect(vm.boundStops[vm.boundStopIndex!].label == "8")
    }

    /// Driving the dial to a new stop sets the bound leg and re-solves the
    /// triangle live: opening the aperture two stops (f/8 → f/4) lets in 4× the
    /// light, so the solved shutter runs 4× faster — the ticket's demo behavior.
    @Test func steppingTheBoundLegResolvesTheTriangleLive() async {
        let source = FakeLightSource()
        let vm = MeterViewModel(source: source)
        vm.setAperture(8)
        vm.bindDial(to: .aperture)
        await vm.start()

        source.emit(LightReading(iso: 100, exposureDuration: 1.0 / 128.0, aperture: 16))
        await waitUntil { vm.triangle.shutter != nil }
        let atF8 = vm.triangle.shutter!.value
        let f8Index = vm.boundStopIndex!

        // Two 1/3-stop clicks per stop → six clicks opens two full stops to f/4.
        vm.setBoundStopIndex(f8Index - 6)
        #expect(vm.triangle.aperture?.label == "4")
        #expect(abs(atF8 / vm.triangle.shutter!.value - 4) < 0.01)
    }

    /// Stepping past the end of a scale clamps to the last stop rather than
    /// running off the end.
    @Test func steppingClampsToTheScaleBounds() {
        let vm = MeterViewModel(source: FakeLightSource())
        vm.bindDial(to: .iso)

        vm.setBoundStopIndex(9_999)
        #expect(vm.boundStopIndex == PhotographicScale.iso.stops.count - 1)

        vm.setBoundStopIndex(-9_999)
        #expect(vm.boundStopIndex == 0)
    }

    // MARK: - Priority mode

    /// Aperture-priority is the default: the shutter is the solved leg and the
    /// two set legs (ISO, aperture) are editable.
    @Test func aperturePriorityIsTheDefaultMode() {
        let vm = MeterViewModel(source: FakeLightSource())
        #expect(vm.mode == .aperturePriority)
        #expect(vm.triangle.solved == .shutter)
        #expect(vm.isEditable(.aperture))
        #expect(!vm.isEditable(.shutter))
    }

    /// The ticket's demo: switching to shutter-priority makes the shutter an
    /// input and the aperture the solved value. The chip routing flips with it —
    /// shutter becomes editable, aperture becomes solved.
    @Test func switchingToShutterPriorityFlipsWhichLegIsSolved() async {
        let source = FakeLightSource()
        let vm = MeterViewModel(source: source)
        vm.setShutter(1.0 / 128)
        await vm.start()

        source.emit(LightReading(iso: 100, exposureDuration: 1.0 / 128.0, aperture: 16))
        await waitUntil { vm.triangle.shutter != nil }
        // Aperture-priority to start: shutter solved, aperture an input.
        #expect(vm.triangle.solved == .shutter)

        vm.setMode(.shutterPriority)

        #expect(vm.mode == .shutterPriority)
        #expect(vm.triangle.solved == .aperture)
        #expect(vm.isEditable(.shutter))
        #expect(!vm.isEditable(.aperture))
        // Sunny 16, EV 15 at ISO 100, 1/125 solves the aperture back to f/16.
        #expect(vm.triangle.shutter?.label == "1/125")
        #expect(vm.triangle.aperture?.label == "16")
    }

    /// `toggleMode()` flips between the two modes — the single mode control.
    @Test func toggleModeSwitchesBothWays() {
        let vm = MeterViewModel(source: FakeLightSource())
        vm.toggleMode()
        #expect(vm.mode == .shutterPriority)
        vm.toggleMode()
        #expect(vm.mode == .aperturePriority)
    }

    /// Switching modes unbinds the dial if it was bound to the leg that becomes
    /// solved (and so non-editable) — the dial must never drive a computed leg.
    @Test func switchingModeUnbindsTheDialFromANowSolvedLeg() {
        let vm = MeterViewModel(source: FakeLightSource())
        vm.bindDial(to: .aperture)
        #expect(vm.boundComponent == .aperture)

        // Shutter-priority solves the aperture, so the aperture dial must unbind.
        vm.setMode(.shutterPriority)
        #expect(vm.boundComponent == nil)
    }

    /// A dial bound to a leg that stays editable across the switch is left alone.
    @Test func switchingModeKeepsADialBoundToAStillEditableLeg() {
        let vm = MeterViewModel(source: FakeLightSource())
        vm.bindDial(to: .iso) // ISO is a set input in both modes
        vm.setMode(.shutterPriority)
        #expect(vm.boundComponent == .iso)
    }

    // MARK: - Metering pattern

    /// Center-weighted average is the default: no spot is placed, and the source
    /// is left on the whole-frame read until the photographer asks for a spot.
    @Test func averageIsTheDefaultPattern() {
        let vm = MeterViewModel(source: FakeLightSource())
        #expect(vm.pattern == .average)
        #expect(vm.spot == nil)
    }

    /// Tapping the preview to place a spot flips the pattern to spot and routes
    /// the tapped point to the source as its AE region of interest.
    @Test func placingASpotSwitchesToSpotAndRoutesThePoint() {
        let source = FakeLightSource()
        let vm = MeterViewModel(source: source)

        let point = CGPoint(x: 0.25, y: 0.75)
        vm.placeSpot(at: point)

        #expect(vm.pattern == .spot)
        #expect(vm.spot == point)
        #expect(source.lastExposurePoint == point)
    }

    /// Placing another spot moves the region of interest to the new point.
    @Test func placingANewSpotRoutesTheNewPoint() {
        let source = FakeLightSource()
        let vm = MeterViewModel(source: source)

        vm.placeSpot(at: CGPoint(x: 0.2, y: 0.2))
        let highlight = CGPoint(x: 0.8, y: 0.3)
        vm.placeSpot(at: highlight)

        #expect(vm.spot == highlight)
        #expect(source.lastExposurePoint == highlight)
    }

    /// Points outside the frame (e.g. a tap on the letterboxed edge) are clamped
    /// into the valid `[0, 1]` device range before reaching the camera.
    @Test func placingASpotClampsToTheDeviceRange() {
        let source = FakeLightSource()
        let vm = MeterViewModel(source: source)

        vm.placeSpot(at: CGPoint(x: -0.4, y: 1.6))

        #expect(vm.spot == CGPoint(x: 0, y: 1))
        #expect(source.lastExposurePoint == CGPoint(x: 0, y: 1))
    }

    /// Switching back to average resets the source to the whole-frame read.
    @Test func switchingToAverageRoutesTheWholeFrame() {
        let source = FakeLightSource()
        let vm = MeterViewModel(source: source)
        vm.placeSpot(at: CGPoint(x: 0.3, y: 0.3))

        vm.setPattern(.average)

        #expect(vm.pattern == .average)
        #expect(source.lastExposurePoint == nil)
        // The average reset is a real routed call, not the empty initial state.
        #expect(source.exposurePointCallCount == 2)
    }

    /// Switching to spot with no prior spot defaults the region of interest to the
    /// frame center, so there is always a point to meter and show a reticle at.
    @Test func switchingToSpotWithNoPriorSpotDefaultsToCenter() {
        let source = FakeLightSource()
        let vm = MeterViewModel(source: source)

        vm.setPattern(.spot)

        #expect(vm.spot == CGPoint(x: 0.5, y: 0.5))
        #expect(source.lastExposurePoint == CGPoint(x: 0.5, y: 0.5))
    }

    /// Re-selecting the active pattern is a no-op — it neither re-routes nor
    /// disturbs the placed spot.
    @Test func reselectingTheActivePatternDoesNothing() {
        let source = FakeLightSource()
        let vm = MeterViewModel(source: source)
        vm.placeSpot(at: CGPoint(x: 0.4, y: 0.6))
        let callsAfterPlacing = source.exposurePointCallCount

        vm.setPattern(.spot)

        #expect(source.exposurePointCallCount == callsAfterPlacing)
    }

    /// `togglePattern()` flips between average and spot — the single control.
    @Test func togglePatternSwitchesBothWays() {
        let vm = MeterViewModel(source: FakeLightSource())
        vm.togglePattern()
        #expect(vm.pattern == .spot)
        vm.togglePattern()
        #expect(vm.pattern == .average)
    }

    /// A spot placed before metering starts is applied to the source when metering
    /// begins, so the first session already meters the chosen point.
    @Test func startAppliesTheCurrentPatternToTheSource() async {
        let source = FakeLightSource()
        let vm = MeterViewModel(source: source)
        let point = CGPoint(x: 0.6, y: 0.4)
        vm.placeSpot(at: point)
        let callsBeforeStart = source.exposurePointCallCount

        await vm.start()

        // start() must route the point afresh — not merely leave the value
        // placeSpot(at:) already set — so the new session meters it from the off.
        #expect(source.exposurePointCallCount == callsBeforeStart + 1)
        #expect(source.lastExposurePoint == point)
    }

    // MARK: - Priority mode (continued)

    /// In shutter-priority the shutter is a dial-able input: stepping it re-solves
    /// the aperture live. A slower shutter (more light) stops the aperture down.
    @Test func steppingTheShutterInShutterPriorityResolvesTheAperture() async {
        let source = FakeLightSource()
        let vm = MeterViewModel(source: source)
        vm.setMode(.shutterPriority)
        vm.setShutter(1.0 / 128)
        vm.bindDial(to: .shutter)
        await vm.start()

        source.emit(LightReading(iso: 100, exposureDuration: 1.0 / 128.0, aperture: 16))
        await waitUntil { vm.triangle.aperture != nil }
        let atFast = vm.triangle.aperture!.value
        let fastIndex = vm.boundStopIndex!

        // Shutter stops ascend by duration, so a higher index is a slower speed.
        // Six 1/3-stop clicks slows two full stops (1/125 → 1/30), ~4× the light,
        // so the solved aperture stops down two stops (f/16 → f/32, 2×N).
        vm.setBoundStopIndex(fastIndex + 6)
        #expect(vm.triangle.shutter?.label == "1/30")
        #expect(abs(vm.triangle.aperture!.value / atFast - 2) < 0.02)
    }
}
