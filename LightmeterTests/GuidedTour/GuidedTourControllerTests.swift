import Foundation
import Testing
@testable import Lightmeter

@MainActor
struct GuidedTourControllerTests {
    @Test("First-run tour waits for live metering", .bug("https://github.com/guillermo-rebolledo/lightmeter/issues/27"))
    func firstRunTourWaitsForLiveMetering() {
        let (controller, _) = makeController()

        controller.update(for: .idle, isMeterReady: false, isVoiceOverRunning: false)
        #expect(controller.isPresented == false)

        controller.update(for: .metering, isMeterReady: false, isVoiceOverRunning: false)
        #expect(controller.isPresented == false)

        controller.update(for: .metering, isMeterReady: true, isVoiceOverRunning: false)
        #expect(controller.isPresented)
        #expect(controller.currentStep == .evReadout)
    }

    @Test("Completing or skipping the tour records it as seen", arguments: [false, true])
    func endingTourRecordsSeen(skip: Bool) {
        let (controller, preferences) = makeController()
        controller.update(for: .metering, isMeterReady: true, isVoiceOverRunning: false)

        if skip {
            controller.skip()
        } else {
            for _ in GuidedTourStep.allCases {
                controller.advance()
            }
        }

        #expect(controller.isPresented == false)
        #expect(preferences.hasSeenGuidedTour)
    }

    @Test(
        "Tour follows the photographer's mental model",
        .bug("https://github.com/guillermo-rebolledo/lightmeter/issues/28")
    )
    func tourFollowsMentalModelOrder() {
        let (controller, _) = makeController()
        controller.update(for: .metering, isMeterReady: true, isVoiceOverRunning: false)

        for (index, expectedStep) in GuidedTourStep.allCases.enumerated() {
            #expect(controller.currentStep == expectedStep)
            #expect(controller.progressLabel == "\(index + 1) of 6")
            controller.advance()
        }

        #expect(controller.isPresented == false)
    }

    @Test(
        "Entering spot and dial steps prepares their real controls",
        .bug("https://github.com/guillermo-rebolledo/lightmeter/issues/28")
    )
    func enteringStepsChoreographsMeterState() {
        let (controller, _, model) = makeControllerWithModel()
        controller.update(for: .metering, isMeterReady: true, isVoiceOverRunning: false)

        controller.advance()
        #expect(controller.currentStep == .meteringPattern)
        #expect(model.pattern == .spot)
        #expect(model.spot == .frameCenter)

        controller.advance()
        controller.advance()
        #expect(controller.currentStep == .dial)
        #expect(model.boundComponent == .iso)
        #expect(model.dialLabels.isEmpty == false)
    }

    @Test("Live readings do not reset a tour in progress")
    func liveReadingsDoNotResetProgress() {
        let (controller, _, model) = makeControllerWithModel()
        controller.update(for: .metering, isMeterReady: true, isVoiceOverRunning: false)
        controller.advance()
        #expect(controller.currentStep == .meteringPattern)

        controller.update(for: .metering, isMeterReady: true, isVoiceOverRunning: false)

        #expect(controller.currentStep == .meteringPattern)
        #expect(model.pattern == .spot)
    }

    @Test(
        "Finishing or skipping restores the photographer's setup",
        .bug("https://github.com/guillermo-rebolledo/lightmeter/issues/28"),
        arguments: [false, true]
    )
    func endingTourRestoresMeterState(skip: Bool) {
        let (controller, _, model) = makeControllerWithModel()
        model.setMode(.shutterPriority)
        model.setISO(800)
        model.setShutter(1.0 / 30)
        model.setAperture(4)
        model.setCompensation(-1)
        model.placeSpot(at: CGPoint(x: 0.2, y: 0.8))
        model.bindCompensationDial()

        controller.update(for: .metering, isMeterReady: true, isVoiceOverRunning: false)
        controller.advance()
        controller.advance()
        controller.advance()

        if skip {
            controller.skip()
        } else {
            while controller.isPresented {
                controller.advance()
            }
        }

        #expect(model.mode == .shutterPriority)
        #expect(model.iso == 800)
        #expect(model.shutter == 1.0 / 30)
        #expect(model.aperture == 4)
        #expect(model.compensation == -1)
        #expect(model.pattern == .spot)
        #expect(model.spot == CGPoint(x: 0.2, y: 0.8))
        #expect(model.isCompensationDialBound)
    }

    @Test(
        "Final step demonstrates Hold and restores live metering",
        .bug("https://github.com/guillermo-rebolledo/lightmeter/issues/28")
    )
    func finalStepDemonstratesHold() async throws {
        let preferences = MeterPreferences(defaults: nil)
        let source = FakeLightSource()
        let model = MeterViewModel(source: source, preferences: preferences)
        let controller = GuidedTourController(preferences: preferences, model: model)
        await model.start()
        source.emit(LightReading(iso: 100, exposureDuration: 1.0 / 125, aperture: 8))
        await waitUntil { model.latestReading != nil }
        _ = try #require(model.latestReading)

        controller.update(for: .metering, isMeterReady: true, isVoiceOverRunning: false)
        for _ in 0..<5 {
            controller.advance()
        }

        #expect(controller.currentStep == .settings)
        #expect(model.isFrozen)

        controller.advance()

        #expect(model.isFrozen == false)
    }

    @Test("Returning users are not shown the automatic tour")
    func returningUsersAreNotShownAutomaticTour() {
        let (controller, preferences) = makeController()
        preferences.hasSeenGuidedTour = true

        controller.update(for: .metering, isMeterReady: true, isVoiceOverRunning: false)

        #expect(controller.isPresented == false)
    }

    @Test("Manual replay shows the tour again when metering is live")
    func manualReplayShowsTour() {
        let (controller, preferences) = makeController()
        preferences.hasSeenGuidedTour = true

        controller.requestReplay(
            for: .metering,
            isMeterReady: true,
            isVoiceOverRunning: false
        )

        #expect(controller.isPresented)
        #expect(controller.currentStep == .evReadout)
    }

    @Test(
        "Camera failures silently consume the automatic tour",
        arguments: [MeterViewModel.Status.denied, .unavailable]
    )
    func cameraFailuresConsumeTour(status: MeterViewModel.Status) {
        let (controller, preferences) = makeController()

        controller.update(for: status, isMeterReady: false, isVoiceOverRunning: false)

        #expect(controller.isPresented == false)
        #expect(preferences.hasSeenGuidedTour)
    }

    @Test("VoiceOver suppresses and consumes the tour")
    func voiceOverSuppressesTour() {
        let (controller, preferences) = makeController()

        controller.update(for: .metering, isMeterReady: true, isVoiceOverRunning: true)

        #expect(controller.isPresented == false)
        #expect(preferences.hasSeenGuidedTour)
    }

    @Test("Manual replay waits until metering becomes live")
    func manualReplayWaitsForMetering() {
        let (controller, preferences) = makeController()
        preferences.hasSeenGuidedTour = true

        controller.requestReplay(
            for: .idle,
            isMeterReady: false,
            isVoiceOverRunning: false
        )
        #expect(controller.isPresented == false)

        controller.update(for: .metering, isMeterReady: true, isVoiceOverRunning: false)
        #expect(controller.isPresented)
    }

    private func makeController() -> (GuidedTourController, MeterPreferences) {
        let preferences = MeterPreferences(defaults: nil)
        return (GuidedTourController(preferences: preferences), preferences)
    }

    private func makeControllerWithModel()
        -> (GuidedTourController, MeterPreferences, MeterViewModel) {
        let preferences = MeterPreferences(defaults: nil)
        let model = MeterViewModel(source: FakeLightSource(), preferences: preferences)
        let controller = GuidedTourController(preferences: preferences, model: model)
        return (controller, preferences, model)
    }

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
}
