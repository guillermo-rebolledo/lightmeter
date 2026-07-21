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

    init(defaults: UserDefaults = .standard) {
        let camera = CameraLightSource()
        let preferences = MeterPreferences(defaults: defaults)
        _camera = State(initialValue: camera)
        _model = State(initialValue: MeterViewModel(source: camera, preferences: preferences))
        _preferences = State(initialValue: preferences)
        _tour = State(initialValue: GuidedTourController(preferences: preferences))
    }

    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                Color.black.ignoresSafeArea()

                switch model.status {
                case .idle, .metering:
                    CameraPreviewView(
                        session: camera.session,
                        spot: model.spot,
                        isSpotActive: model.pattern == .spot,
                        onPlaceSpot: { model.placeSpot(at: $0) }
                    )
                    .ignoresSafeArea()
                    meterOverlay
                case .denied:
                    CameraStatusView(status: .denied)
                case .unavailable:
                    CameraStatusView(status: .unavailable)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink(value: Destination.settings) {
                        Label("Settings", systemImage: "gearshape")
                    }
                }
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
        .overlayPreferenceValue(GuidedTourAnchorPreferenceKey.self) { anchors in
            GeometryReader { geometry in
                if tour.isPresented,
                   let step = tour.currentStep,
                   let anchor = anchors[step] {
                    GuidedTourOverlay(
                        step: step,
                        targetFrame: geometry[anchor],
                        progressLabel: tour.progressLabel,
                        onAdvance: tour.advance,
                        onSkip: tour.skip
                    )
                }
            }
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

    /// The metering HUD floated over the preview near the bottom edge: the scene
    /// EV@ISO100 reference above the three exposure-triangle chips, with a
    /// permanent slot for the arc dial below them.
    private var meterOverlay: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: 16) {
                evReadout
                HStack(spacing: 10) {
                    FreezeButton(
                        isFrozen: model.isFrozen,
                        canFreeze: model.latestReading != nil,
                        onToggle: model.toggleFreeze
                    )
                    CompensationControl(
                        value: model.compensationLabel,
                        isBound: model.isCompensationDialBound,
                        onSelect: model.bindCompensationDial
                    )
                }
                AdvisoriesView(advisories: model.advisories)
                MeteringPatternToggle(
                    pattern: model.pattern,
                    onSelect: { model.setPattern($0) }
                )
                PriorityModeToggle(
                    mode: model.mode,
                    onSelect: { model.setMode($0) }
                )
                ExposureChipsView(
                    triangle: model.triangle,
                    boundComponent: model.boundComponent,
                    onSelect: { model.bindDial(to: $0) }
                )
            }
            .padding(20)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            .padding(.horizontal, 16)

            dial
                .padding(.top, 8)
        }
        .padding(.bottom, 44)
    }

    /// The shared arc dial stays mounted so its gesture area is available before
    /// a target is bound; only its visual content changes visibility.
    private var dial: some View {
        ArcDialView(
            labels: model.dialLabels,
            selectedIndex: model.dialStopIndex,
            caption: model.dialCaption,
            onSelect: { model.setDialStopIndex($0) }
        )
    }

    /// The EV@ISO100 readout — the raw reference for the scene's light level.
    private var evReadout: some View {
        VStack(spacing: 2) {
            Text("EV @ ISO 100")
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(1.5)

            Text(model.ev.map { String(format: "%.1f", $0) } ?? "—")
                .font(.system(size: 46, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white)
                .contentTransition(.numericText())
        }
        .animation(reduceMotion ? nil : .snappy, value: model.ev)
        .guidedTourAnchor(.evReadout)
    }

    private func showTour() {
        tour.requestReplay(
            for: model.status,
            isMeterReady: model.latestReading != nil,
            isVoiceOverRunning: isVoiceOverRunning
        )
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
    }
}

#Preview {
    ContentView()
        .preferredColorScheme(.dark)
}
