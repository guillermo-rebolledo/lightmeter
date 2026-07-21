import SwiftUI

/// The meter screen: a live camera preview as the hero, with the scene's
/// EV@ISO100 read out over it and updating in real time. Falls back to a graceful
/// explanation when camera access is denied or capture is unavailable.
struct ContentView: View {
    private enum Destination: Hashable {
        case settings
    }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var camera: CameraLightSource
    @State private var model: MeterViewModel
    @State private var preferences: MeterPreferences

    init(defaults: UserDefaults = .standard) {
        let camera = CameraLightSource()
        let preferences = MeterPreferences(defaults: defaults)
        _camera = State(initialValue: camera)
        _model = State(initialValue: MeterViewModel(source: camera, preferences: preferences))
        _preferences = State(initialValue: preferences)
    }

    var body: some View {
        NavigationStack {
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
                    SettingsView(preferences: preferences)
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .tint(.yellow)
            .task { await model.start() }
            .onDisappear { model.stop() }
        }
    }

    /// The metering HUD floated over the preview near the bottom edge: the scene
    /// EV@ISO100 reference above the three exposure-triangle chips, with the arc
    /// dial swinging in below when a chip is bound.
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
        .animation(reduceMotion ? nil : .snappy, value: model.dialCaption)
    }

    /// The shared arc dial, shown while an exposure chip or EV compensation is
    /// bound. It drives that target by detent index and re-solves live.
    @ViewBuilder
    private var dial: some View {
        if let index = model.dialStopIndex, let caption = model.dialCaption {
            ArcDialView(
                labels: model.dialLabels,
                selectedIndex: index,
                caption: caption,
                onSelect: { model.setDialStopIndex($0) }
            )
            .transition(reduceMotion
                ? .opacity
                : .move(edge: .bottom).combined(with: .opacity))
        }
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
    }
}

#Preview {
    ContentView()
        .preferredColorScheme(.dark)
}
