import SwiftUI
import UIKit

/// The meter screen: a live camera preview as the hero, with the scene's
/// EV@ISO100 read out over it and updating in real time. Falls back to a graceful
/// denied state when camera access isn't granted.
struct ContentView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var camera: CameraLightSource
    @State private var model: MeterViewModel

    init() {
        let camera = CameraLightSource()
        _camera = State(initialValue: camera)
        _model = State(initialValue: MeterViewModel(source: camera))
    }

    var body: some View {
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
                DeniedView()
            }
        }
        .tint(.yellow)
        .task { await model.start() }
        .onDisappear { model.stop() }
    }

    /// The metering HUD floated over the preview near the bottom edge: the scene
    /// EV@ISO100 reference above the three exposure-triangle chips, with the arc
    /// dial swinging in below when a chip is bound.
    private var meterOverlay: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: 16) {
                evReadout
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
        .animation(reduceMotion ? nil : .snappy, value: model.boundComponent)
    }

    /// The arc dial, shown only while a chip is bound. It drives the bound leg by
    /// stop index and re-solves the triangle live.
    @ViewBuilder
    private var dial: some View {
        if let boundComponent = model.boundComponent, let index = model.boundStopIndex {
            ArcDialView(
                stops: model.boundStops,
                selectedIndex: index,
                caption: boundComponent.caption,
                onSelect: { model.setBoundStopIndex($0) }
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
        .animation(.snappy, value: model.ev)
    }
}

/// Shown when camera access is denied or restricted, with a route to Settings.
private struct DeniedView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "video.slash")
                .font(.system(size: 52, weight: .thin))
                .foregroundStyle(.white)

            Text("Camera access needed")
                .font(.title2.weight(.semibold))
                .foregroundStyle(.white)

            Text("Lightmeter reads the light from your camera to meter exposure. Enable camera access in Settings to start metering.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                Link("Open Settings", destination: settingsURL)
                    .font(.body.weight(.semibold))
                    .padding(.top, 4)
            }
        }
        .padding()
    }
}

#Preview {
    ContentView()
        .preferredColorScheme(.dark)
}
