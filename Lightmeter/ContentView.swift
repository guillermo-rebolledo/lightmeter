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
            // Resolve tour anchors in the same full-screen space the spotlight
            // draws into. An outer overlay under-reports Y by the top safe area,
            // which shifts every cutout upward by roughly one control row.
            .overlayPreferenceValue(GuidedTourAnchorPreferenceKey.self) { anchors in
                GeometryReader { geometry in
                    if tour.isPresented,
                       let step = tour.currentStep,
                       let targetFrame = tourTargetFrame(
                        for: step,
                        anchors: anchors,
                        geometry: geometry
                       ) {
                        GuidedTourOverlay(
                            step: step,
                            targetFrame: targetFrame,
                            progressLabel: tour.progressLabel,
                            onAdvance: tour.advance,
                            onSkip: tour.skip
                        )
                    }
                }
                .ignoresSafeArea()
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
                    .guidedTourAnchor(.compensation)
                }
                // Freeze advisory height for the tour so live warnings cannot
                // shove spotlight targets between steps.
                AdvisoriesView(advisories: tourAdvisories ?? model.advisories)
                    .opacity(tour.isPresented ? 0 : 1)
                    .allowsHitTesting(tour.isPresented == false)
                    .accessibilityHidden(tour.isPresented)
                MeteringPatternToggle(
                    pattern: model.pattern,
                    onSelect: { model.setPattern($0) }
                )
                .guidedTourAnchor(.meteringPattern)
                VStack(spacing: 16) {
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
                .guidedTourAnchor(.priorityAndChips)
            }
            .padding(20)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            .padding(.horizontal, 16)

            dial
                .padding(.top, 8)
                .guidedTourAnchor(.arcDial)
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

    /// Toolbar items don't publish reliable content-space anchors, so Settings
    /// is synthesized to the standard trailing nav-bar button slot.
    private func tourTargetFrame(
        for step: GuidedTourStep,
        anchors: [GuidedTourStep: Anchor<CGRect>],
        geometry: GeometryProxy
    ) -> CGRect? {
        switch step {
        case .settings:
            // Full-bleed geometry often reports only the sensor/status inset.
            // Toolbar items sit in the 44pt nav-bar band beneath that, so when
            // the inset is status-only we add the bar height before bottom-
            // aligning the cutout to the content edge.
            let size = 44.0
            let trailing = 16.0
            let barHeight = 44.0
            let topInset = geometry.safeAreaInsets.top
            let contentTop = topInset < barHeight + 30
                ? topInset + barHeight
                : topInset
            return CGRect(
                x: geometry.size.width - trailing - size,
                y: contentTop - size,
                width: size,
                height: size
            )
        case .evReadout, .meteringPattern, .priorityAndChips, .arcDial, .compensation:
            guard let anchor = anchors[step] else { return nil }
            return geometry[anchor]
        }
    }
}

#Preview {
    ContentView()
        .preferredColorScheme(.dark)
}
