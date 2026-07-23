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
                        evReadout: evReadout,
                        onPlaceSpot: { model.placeSpot(at: $0) }
                    )
                    .ignoresSafeArea()
                    meterLayout
                    // EV's home is the metered point, not the hero: on the
                    // reticle in spot metering (drawn by the preview above), and
                    // here as a quiet label when the whole frame is averaged.
                    secondaryEVReadout
                    // The occasional controls live over the preview in the
                    // top-left — mirroring the settings gear opposite them —
                    // rather than inside the HUD card, so both states are
                    // always readable and the card stays clear.
                    statusPills
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
            if isLandscape {
                LandscapeMeterLayout(
                    model: model,
                    advisories: advisories,
                    isTourActive: tour.isPresented,
                    tourStep: activeTourStep
                )
            } else {
                PortraitMeterLayout(
                    model: model,
                    advisories: advisories,
                    isTourActive: tour.isPresented
                )
            }
        }
        .animation(reduceMotion ? nil : .smooth, value: verticalSizeClass)
    }

    /// The metering pattern and compensation status pills, floated over the
    /// preview in the top-left — the mirror of the settings gear opposite them.
    /// Owned here rather than by either layout so the pair sits in the same place
    /// in both orientations (the landscape drawer hugs the trailing edge, leaving
    /// the leading corner clear).
    private var statusPills: some View {
        MeterStatusPills(model: model, tourStep: activeTourStep)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(.top, 4)
            .padding(.leading, 8)
    }

    /// Where EV is shown over the preview, and what it reads — derived from the
    /// already-published `pattern`/`spot`/`ev`. Owned here because both homes
    /// hang off the preview: the reticle badge inside `CameraPreviewView`, and
    /// the average-metering label below.
    private var evReadout: PreviewEVReadout? {
        PreviewEVReadout(pattern: model.pattern, spot: model.spot, ev: model.ev)
    }

    /// The average-metering EV label, floated at the top of the preview —
    /// subordinate to the HUD's hero, and clear of the frame's center where the
    /// photographer is composing. Centered *below* the status-pill row rather
    /// than beside it, so the widest pair of pills can't crowd it on a narrow
    /// phone; the pills' revealed editor is transient and draws over it.
    private var secondaryEVReadout: some View {
        PreviewEVReadoutView(readout: evReadout)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .padding(.top, statusPillRowHeight + 12)
    }

    /// The status pills' tappable row height — what the EV label clears. Scaled
    /// with Dynamic Type alongside the pills' own footnote text, so the label
    /// doesn't slide up into a row that grew.
    @ScaledMetric(relativeTo: .footnote) private var statusPillRowHeight: CGFloat = 44

    /// The step the tour is actually showing — only drive the pills' tour
    /// override while the tour is presented, otherwise their reveal stays purely
    /// view-local.
    private var activeTourStep: GuidedTourStep? {
        tour.isPresented ? tour.currentStep : nil
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
