import SwiftUI

/// The meter screen: a live camera preview as the hero, with the scene's
/// EV@ISO100 read out over it and updating in real time. Falls back to a graceful
/// explanation when camera access is denied or capture is unavailable.
struct ContentView: View {
    private enum Destination: Hashable {
        case settings
    }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityVoiceOverEnabled) private var isVoiceOverRunning
    @State private var camera: CameraLightSource
    @State private var model: MeterViewModel
    @State private var preferences: MeterPreferences
    @State private var tour: GuidedTourController
    @State private var path: [Destination] = []
    /// Advisories frozen for the tour's lifetime so their height cannot drift.
    @State private var tourAdvisories: [ExposureAdvisory]?

    init(defaults: UserDefaults = .standard) {
        let camera = CameraLightSource()
        let preferences = MeterPreferences(defaults: defaults)
        let model = MeterViewModel(source: camera, preferences: preferences)
        _camera = State(initialValue: camera)
        _model = State(initialValue: model)
        _preferences = State(initialValue: preferences)
        _tour = State(
            initialValue: GuidedTourController(
                preferences: preferences,
                model: model
            )
        )
    }

    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                Color.black.ignoresSafeArea()

                switch model.status {
                case .idle, .metering:
                    CameraPreviewView(
                        session: camera.session,
                        captureDevice: camera.captureDevice,
                        spot: model.spot,
                        isSpotActive: model.pattern == .spot,
                        onPlaceSpot: { model.placeSpot(at: $0) }
                    )
                    .ignoresSafeArea()
                    PortraitMeterLayout(
                        model: model,
                        advisories: tourAdvisories ?? model.advisories,
                        isTourActive: tour.isPresented
                    )
                case .denied:
                    CameraStatusView(status: .denied)
                case .unavailable:
                    CameraStatusView(status: .unavailable)
                }
            }
            // Own the gear in content space (not ToolbarItem) so the tour
            // anchor and the tappable control share one resolved frame.
            // Avoid `.offset` — it moves pixels without moving layout bounds,
            // which leaves the spotlight stranded away from the gear.
            .overlay(alignment: .topTrailing) {
                NavigationLink(value: Destination.settings) {
                    Label("Settings", systemImage: "gearshape")
                        .labelStyle(.iconOnly)
                        .foregroundStyle(.tint)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .tint(.yellow)
                .guidedTourAnchor(.settings)
                .padding(.top, 4)
                .padding(.trailing, 8)
            }
            // Resolve tour anchors in the same full-screen space the spotlight
            // draws into. An outer overlay under-reports Y by the top safe area,
            // which shifts every cutout upward by roughly one control row.
            .overlayPreferenceValue(GuidedTourAnchorPreferenceKey.self) { anchors in
                GeometryReader { geometry in
                    if tour.isPresented,
                       let step = tour.currentStep,
                       let anchor = anchors[step] {
                        let overlay = GuidedTourOverlay(
                            step: step,
                            targetFrame: geometry[anchor],
                            progressLabel: tour.progressLabel,
                            onAdvance: tour.advance,
                            onSkip: tour.skip
                        )

                        if reduceMotion {
                            // Reduce Motion: re-identifying by step swaps the
                            // overlay so its opacity transition cross-fades with
                            // no positional movement.
                            overlay
                                .id(step)
                                .transition(.opacity)
                        } else {
                            // Stable identity: the changed target frame flows
                            // through the spotlight's animatableData so the
                            // cutout slides and resizes to the next step.
                            overlay
                        }
                    }
                }
                .ignoresSafeArea()
                // Single driver for both paths: the crossfade transition above
                // and the spotlight's frame interpolation are the same `step`
                // change, so one animation keeps the two modes from competing.
                .animation(
                    reduceMotion ? .easeInOut(duration: 0.25) : .snappy,
                    value: tour.currentStep
                )
            }
            .navigationDestination(for: Destination.self) { destination in
                switch destination {
                case .settings:
                    SettingsView(
                        preferences: preferences,
                        onShowTour: showTour
                    )
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .tint(.yellow)
            .task { await model.start() }
            .onDisappear { model.stop() }
        }
        .onChange(of: model.status, initial: true) {
            updateTourState()
        }
        .onChange(of: model.latestReading) {
            updateTourState()
        }
        .onChange(of: isVoiceOverRunning, initial: true) {
            updateTourState()
        }
    }

    private func showTour() {
        tour.requestReplay(
            for: model.status,
            isMeterReady: model.latestReading != nil,
            isVoiceOverRunning: isVoiceOverRunning
        )
        if tour.isPresented, tourAdvisories == nil {
            tourAdvisories = model.advisories
        }
        if path.isEmpty == false {
            path.removeLast()
        }
    }

    private func updateTourState() {
        tour.update(
            for: model.status,
            isMeterReady: model.latestReading != nil,
            isVoiceOverRunning: isVoiceOverRunning
        )
        if tour.isPresented {
            if tourAdvisories == nil {
                tourAdvisories = model.advisories
            }
        } else {
            tourAdvisories = nil
        }
    }

}

#Preview {
    ContentView()
        .preferredColorScheme(.dark)
}
