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
    @Environment(\.verticalSizeClass) private var verticalSizeClass
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
        // Portrait usability variant: the guided tour is disabled branch-only so
        // we can observe whether the new arrangement is discoverable cold. Handing
        // the controller no steps makes it present nothing — the overlay never
        // renders and the meter UI is never covered.
        _tour = State(
            initialValue: GuidedTourController(
                preferences: preferences,
                model: model,
                steps: []
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
                    meterLayout
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
                        // iOS 26: a small Liquid Glass circle; the fallback keeps
                        // the bare tinted icon it has always been.
                        .modifier(GlassCircleBackground())
                }
                .buttonStyle(.plain)
                .tint(.appAccent)
                .guidedTourAnchor(.settings)
                .padding(.top, 4)
                // In landscape the HUD drawer hugs the trailing edge; inset the
                // gear past the drawer's width so it stays over the preview and
                // never disappears beneath the drawer.
                .padding(.trailing, isLandscape ? LandscapeMeterLayout.drawerWidth + 8 : 8)
            }
            // Resolve tour anchors in the same full-screen space the spotlight
            // draws into. An outer overlay under-reports Y by the top safe area,
            // which shifts every cutout upward by roughly one control row.
            .overlayPreferenceValue(GuidedTourAnchorPreferenceKey.self) { anchors in
                GeometryReader { geometry in
                    // Anchored steps wait for their control's resolved frame; the
                    // welcome step has no spotlight and renders a centered card
                    // (nil target) immediately.
                    let targetFrame = tour.currentStep
                        .flatMap { anchors[$0] }
                        .map { geometry[$0] }

                    if tour.isPresented,
                       let step = tour.currentStep,
                       step.hasSpotlight == false || targetFrame != nil {
                        let overlay = GuidedTourOverlay(
                            step: step,
                            targetFrame: targetFrame,
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
            .tint(.appAccent)
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

    /// iPhone landscape: the compact vertical size class drives the edge layout.
    private var isLandscape: Bool { verticalSizeClass == .compact }

    /// The meter HUD, arranged for the current orientation. Both containers
    /// compose the same shared control views (with stable tour anchors) over the
    /// preview, so rotating reflows the controls without tearing down the camera.
    /// The reflow rides a single `verticalSizeClass`-keyed implicit animation —
    /// the drawer slides from the bottom edge to the trailing edge and its controls
    /// glide to their new homes — collapsing to a plain swap under Reduce Motion.
    @ViewBuilder private var meterLayout: some View {
        let advisories = tourAdvisories ?? model.advisories

        Group {
            // Both layouts compose the same shared control strip, so both take
            // the tour step; only drive the strip's tour override while the tour
            // is actually presented, otherwise the strip stays view-local.
            let tourStep = tour.isPresented ? tour.currentStep : nil

            if isLandscape {
                LandscapeMeterLayout(
                    model: model,
                    advisories: advisories,
                    isTourActive: tour.isPresented,
                    tourStep: tourStep
                )
            } else {
                PortraitMeterLayout(
                    model: model,
                    advisories: advisories,
                    isTourActive: tour.isPresented,
                    tourStep: tourStep
                )
            }
        }
        .animation(reduceMotion ? nil : .smooth, value: verticalSizeClass)
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
