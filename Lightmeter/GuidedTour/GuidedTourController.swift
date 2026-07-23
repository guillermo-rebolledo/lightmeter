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
    private let model: MeterViewModel?
    private let steps: [GuidedTourStep]
    private var replayPending = false
    private var savedMeterState: MeterViewModelState?

    init(
        preferences: MeterPreferences,
        model: MeterViewModel? = nil,
        steps: [GuidedTourStep] = GuidedTourStep.allCases
    ) {
        self.preferences = preferences
        self.model = model
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
            guard isPresented == false else { return }
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
        choreographCurrentStep()
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
        savedMeterState = model?.captureState()
        isPresented = true
        choreographCurrentStep()
    }

    private func finish() {
        restoreMeterState()
        isPresented = false
        preferences.hasSeenGuidedTour = true
    }

    private func suppressAndConsumeTour() {
        replayPending = false
        restoreMeterState()
        isPresented = false
        preferences.hasSeenGuidedTour = true
    }

    private func choreographCurrentStep() {
        guard let model, let currentStep else { return }

        switch currentStep {
        case .welcome, .evReadout, .priorityAndChips:
            break
        case .meteringPattern:
            model.setPattern(.spot)
        case .dial:
            if model.boundComponent != .iso {
                model.bindDial(to: .iso)
            }
        case .compensation:
            if model.isCompensationDialBound == false {
                model.bindCompensationDial()
            }
        case .settings:
            if model.isFrozen == false {
                model.toggleFreeze()
            }
        }
    }

    private func restoreMeterState() {
        guard let model, let savedMeterState else { return }
        model.restoreState(savedMeterState)
        self.savedMeterState = nil
    }
}
