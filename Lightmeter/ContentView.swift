import SwiftUI

/// The meter screen: a live camera preview behind the metering HUD, updating in
/// real time. Falls back to a graceful explanation when camera access is denied
/// or capture is unavailable.
///
/// What floats *over* the preview differs by orientation, which is why the two
/// layouts own it: portrait pins the EV headline bar at the top and hangs the
/// status pills under it, while landscape — which has no bar — keeps the pills
/// and the settings gear floating in the two top corners, as both orientations
/// did before #96.
struct ContentView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityVoiceOverEnabled) private var isVoiceOverRunning
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    /// The real camera, or `nil` when the meter is being driven by an injected
    /// source. It is what the preview binds to, so its absence is also what says
    /// "there is no capture device to show" — the condition the stand-in backdrop
    /// answers.
    @State private var camera: CameraLightSource?
    @State private var model: MeterViewModel
    @State private var preferences: MeterPreferences
    @State private var tour: GuidedTourController
    @State private var path: [MeterDestination] = []
    /// Advisories frozen for the tour's lifetime so their height cannot drift.
    @State private var tourAdvisories: [ExposureAdvisory]?

    /// The guided tour's steps on this branch: **none**.
    ///
    /// The portrait usability variant is judged cold — we want to observe whether
    /// the new arrangement (solved-leg hero, padlock, marked chips, top-left pills)
    /// is discoverable without hand-holding, so the tour is disabled branch-only.
    /// Handing the controller no steps makes it present nothing: the overlay never
    /// renders and the meter UI is never covered, in either orientation and from
    /// Settings' replay as well.
    ///
    /// Named rather than inlined so the "off" state is a fact a test can pin. The
    /// tour's rewrite for the new controls is a separate follow-up, conditional on
    /// the variant winning; restoring it is a one-line change here.
    static let guidedTourSteps: [GuidedTourStep] = []

    /// - Parameters:
    ///   - defaults: Where meter preferences are persisted.
    ///   - source: The light source to meter from. Defaults to `nil`, which
    ///     builds and uses the real `CameraLightSource` — production behaviour is
    ///     exactly what it was. A non-`nil` source means there is no capture
    ///     device behind the screen, so the preview is replaced by a stand-in
    ///     backdrop. Only the debug design harness passes one.
    init(defaults: UserDefaults = .standard, source: LightSource? = nil) {
        let camera: CameraLightSource?
        let meteredSource: LightSource
        if let source {
            camera = nil
            meteredSource = source
        } else {
            let realCamera = CameraLightSource()
            camera = realCamera
            meteredSource = realCamera
        }

        let preferences = MeterPreferences(defaults: defaults)
        let model = MeterViewModel(source: meteredSource, preferences: preferences)
        _camera = State(initialValue: camera)
        _model = State(initialValue: model)
        _preferences = State(initialValue: preferences)
        _tour = State(
            initialValue: GuidedTourController(
                preferences: preferences,
                model: model,
                steps: Self.guidedTourSteps
            )
        )
    }

    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                Color.black.ignoresSafeArea()

                switch model.status {
                case .idle, .metering:
                    backdrop
                    meterLayout
                    // EV has no home over the preview any more: it is the
                    // headline of the portrait bar, which `PortraitMeterLayout`
                    // owns. The reticle is a point marker again, carrying no
                    // reading of its own.
                    //
                    // The occasional controls still float over the preview in
                    // landscape, which has no bar to hold them; in portrait they
                    // are owned by the layout, stacked under the bar.
                    if isLandscape {
                        statusPills
                        // …and so does landscape's EV, which the bar reads in
                        // portrait. The variant is portrait-only, so removing
                        // EV's two old homes must not leave this orientation
                        // with no reading at all.
                        landscapeEVLabel
                    }
                case .denied:
                    CameraStatusView(status: .denied)
                case .unavailable:
                    CameraStatusView(status: .unavailable)
                }
            }
            // The floating gear, owned in content space (not a ToolbarItem) so
            // the tour anchor and the tappable control share one resolved frame.
            // Shown wherever the EV headline bar is not carrying a gear of its
            // own — see `showsFloatingGear`.
            .overlay(alignment: .topTrailing) {
                if showsFloatingGear {
                    MeterSettingsGear()
                        .padding(.top, 4)
                        // In landscape the HUD drawer hugs the trailing edge;
                        // inset the gear past the drawer's width so it stays over
                        // the preview and never disappears beneath the drawer.
                        .padding(.trailing, isLandscape ? LandscapeMeterLayout.drawerWidth + 8 : 8)
                }
            }
            // One declaration for the whole meter screen — the HUD, the floating
            // pills, and the gear that sits opposite them — which is what makes
            // landscape inherit the ceiling rather than implement it again.
            // Applied here rather than on the switch above so the gear is capped
            // with everything else: it is a 44pt target over the preview, and an
            // accessibility size grew its glyph until it overlapped the pills.
            // Settings is pushed as its own destination, so it keeps the full
            // Dynamic Type range — it is an ordinary scrolling list with room.
            .meterTextScaling()
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
            .navigationDestination(for: MeterDestination.self) { destination in
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
            .task {
                #if DEBUG
                // Pin the launch clock and begin watching the main thread for the
                // warmup hitch that swallows early ruler drags (#112) — before
                // `start()`, so the watchdog is already probing across the camera
                // warmup it is there to catch. Inert unless launched with
                // `-launch-diagnostics`.
                LaunchDiagnostics.arm()
                #endif
                await model.start()
                #if DEBUG
                // Drives the meter to the state this launch named, or does
                // nothing on an ordinary run. After `start()`, because the
                // harness sets state the same way a photographer would — on a
                // running meter, through the same entry points.
                await DesignHarness.applyLaunchState(to: model)
                #endif
            }
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

    /// Whether the meter itself is on screen, as opposed to one of the two
    /// camera-refused states.
    private var isShowingMeter: Bool {
        switch model.status {
        case .idle, .metering: true
        case .denied, .unavailable: false
        }
    }

    /// Whether the gear floats in the corner rather than riding the EV headline
    /// bar. True in landscape, which has no bar — and true in portrait whenever
    /// the meter is not on screen, because the bar goes with it: a denied or
    /// unavailable camera would otherwise leave the app's *own* Settings (stop
    /// increment, calibration) with no route to it at all. `CameraStatusView`'s
    /// link opens iOS Settings, which is a different destination.
    private var showsFloatingGear: Bool {
        isLandscape || isShowingMeter == false
    }

    /// What sits behind the HUD: the live camera preview — the hero — whenever
    /// there is a capture device, and the design harness' stand-in scene when
    /// there isn't. Production always takes the first branch.
    @ViewBuilder private var backdrop: some View {
        if let camera {
            CameraPreviewView(
                session: camera.session,
                captureDevice: camera.captureDevice,
                spot: model.spot,
                isSpotActive: model.pattern == .spot,
                onPlaceSpot: { model.placeSpot(at: $0) }
            )
            .ignoresSafeArea()
        } else {
            standInBackdrop
        }
    }

    /// The backdrop where there is no capture device. Only the debug design
    /// harness can reach it — a Release build has no way to inject a source, so
    /// `camera` is never `nil` and this branch never renders.
    @ViewBuilder private var standInBackdrop: some View {
        #if DEBUG
        StandInSceneView(
            scene: DesignHarness.backdropScene,
            spot: model.spot,
            isSpotActive: model.pattern == .spot,
            onPlaceSpot: { model.placeSpot(at: $0) }
        )
        #else
        Color.black.ignoresSafeArea()
        #endif
    }

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
                    isTourActive: tour.isPresented,
                    tourStep: activeTourStep
                )
            }
        }
        .animation(reduceMotion ? nil : .smooth, value: verticalSizeClass)
    }

    /// **Landscape's** metering pattern and compensation status pills, floated
    /// over the preview in the top-left — the mirror of the settings gear
    /// opposite them. The landscape drawer hugs the trailing edge, which is what
    /// leaves this corner clear. Portrait stacks the same pair under its EV
    /// headline bar instead, so the bar's corner is not fought over.
    private var statusPills: some View {
        MeterStatusPills(model: model, tourStep: activeTourStep)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(.top, 4)
            .padding(.leading, 8)
    }

    /// Landscape's quiet EV label, floated at the top of the preview — where EV
    /// was read in this orientation before the portrait bar took it over, and
    /// still is. Clear of the frame's center, where the photographer is composing.
    private var landscapeEVLabel: some View {
        LandscapeEVLabel(
            readout: EVHeadlineReadout(ev: model.ev, triangle: model.triangle)
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(.top, 8)
    }

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
