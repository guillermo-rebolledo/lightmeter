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
    /// The real camera, or `nil` when the meter is being driven by an injected
    /// source. It is what the preview binds to, so its absence is also what says
    /// "there is no capture device to show" — the condition the stand-in backdrop
    /// answers.
    @State private var camera: CameraLightSource?
    @State private var model: MeterViewModel
    @State private var preferences: MeterPreferences
    @State private var tour: GuidedTourController
    @State private var path: [Destination] = []
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
                        // On the glass path, a small Liquid Glass circle; on the
                        // fallback, the bare tinted icon it has always been.
                        .glassSurface(.settingsGear)
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
            .task {
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
                evReadout: evReadout,
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
            evReadout: evReadout,
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

    /// The status pills' own row height — what the EV label clears — scaled with
    /// Dynamic Type alongside the pills' footnote text, so the label doesn't
    /// slide up into a row that grew.
    @ScaledMetric(relativeTo: .footnote)
    private var statusPillRowHeight: CGFloat = MeterStatusPills.rowHeight

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
