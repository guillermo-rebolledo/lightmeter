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
            controller.advance()
        }

        #expect(controller.isPresented == false)
        #expect(preferences.hasSeenGuidedTour)
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
}
