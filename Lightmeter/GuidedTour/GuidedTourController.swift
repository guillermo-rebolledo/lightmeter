import Observation

@MainActor
@Observable
final class GuidedTourController {
    private(set) var isPresented = false
    private(set) var currentStepIndex = 0

    var currentStep: GuidedTourStep? {
        guard steps.indices.contains(currentStepIndex) else { return nil }
        return steps[currentStepIndex]
    }

    var progressLabel: String {
        "\(currentStepIndex + 1) of \(steps.count)"
    }

    private let preferences: MeterPreferences
    private let steps: [GuidedTourStep]
    private var replayPending = false

    init(
        preferences: MeterPreferences,
        steps: [GuidedTourStep] = [.evReadout]
    ) {
        self.preferences = preferences
        self.steps = steps
    }

    func update(
        for status: MeterViewModel.Status,
        isMeterReady: Bool,
        isVoiceOverRunning: Bool
    ) {
        if isVoiceOverRunning {
            suppressAndConsumeTour()
            return
        }

        switch status {
        case .denied, .unavailable:
            suppressAndConsumeTour()
        case .metering:
            guard isMeterReady else { return }
            guard replayPending || preferences.hasSeenGuidedTour == false else { return }
            present()
        case .idle:
            break
        }
    }

    func requestReplay(
        for status: MeterViewModel.Status,
        isMeterReady: Bool,
        isVoiceOverRunning: Bool
    ) {
        replayPending = true
        update(
            for: status,
            isMeterReady: isMeterReady,
            isVoiceOverRunning: isVoiceOverRunning
        )
    }

    func advance() {
        guard isPresented else { return }
        let nextIndex = currentStepIndex + 1
        guard steps.indices.contains(nextIndex) else {
            finish()
            return
        }
        currentStepIndex = nextIndex
    }

    func skip() {
        guard isPresented else { return }
        finish()
    }

    private func present() {
        guard steps.isEmpty == false else {
            finish()
            return
        }
        replayPending = false
        currentStepIndex = 0
        isPresented = true
    }

    private func finish() {
        isPresented = false
        preferences.hasSeenGuidedTour = true
    }

    private func suppressAndConsumeTour() {
        replayPending = false
        isPresented = false
        preferences.hasSeenGuidedTour = true
    }
}
