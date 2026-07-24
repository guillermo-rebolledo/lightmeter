#if DEBUG
import SwiftUI

/// A stand-in for the camera preview: a scene drawn behind the meter UI where
/// there is no capture device to show one.
///
/// The three scenes are the ones the HUD has to survive — a blown-out sky, a dim
/// interior, and a high-contrast mixed scene — because those are where a
/// translucent surface either holds its text or stops being readable. Each
/// carries the light it depicts, so choosing a scene also sets what the meter
/// reads unless the command line says otherwise.
///
/// They are drawn rather than photographed on purpose. A bundled photograph is a
/// binary blob that can't be reviewed in a diff, differs per platform decode, and
/// carries licensing; a drawn scene renders identically on every run, which is
/// what makes two screenshots of the same UI comparable. What glass needs from a
/// backdrop is luminance structure — a hard edge, a hot spot, a deep shadow — and
/// that is exactly what these carry.
enum StandInScene: String, CaseIterable {
    /// Midday blowout: a white-hot sun and a sky the meter reads at the top of
    /// its range. The hardest case for HUD legibility.
    case blownSky = "blown-sky"

    /// A lamp-lit room at night — deep shadow with one warm pool of light. The
    /// case where a dark scrim disappears into the scene behind it.
    case dimInterior = "dim-interior"

    /// A dark room with a blazing window: near-white and near-black meeting at a
    /// hard edge, so a single surface spans the whole contrast range at once.
    case mixedContrast = "mixed-contrast"

    /// The scene's own EV@ISO 100 — used when the command line names a scene but
    /// no explicit EV. Roughly the real-world readings these depict: sunny-16
    /// daylight, a domestic interior, and an indoor frame carrying daylight.
    var nominalEV: Double {
        switch self {
        case .blownSky: 15
        case .dimInterior: 6
        case .mixedContrast: 12
        }
    }
}

/// Draws a ``StandInScene`` full-bleed behind the meter UI, in the place the
/// camera preview would occupy.
///
/// Spot metering is reproduced here too: the reticle normally lives inside
/// `CameraPreviewView`, pinned through the preview layer's device-point
/// conversion, which has nothing to convert without a capture device. The
/// stand-in redraws it in SwiftUI, but from the *same* ``ReticleGeometry`` the
/// shipped one strokes, so the two can't drift apart on the dimensions that
/// matter. What differs is only where it's anchored: view bounds here, sensor
/// space on-device.
struct StandInSceneView: View {
    let scene: StandInScene

    /// The placed spot as a normalized point, mapped straight onto the view's
    /// bounds. Without a preview layer there is no sensor space to map through,
    /// so normalized *is* the frame here.
    var spot: CGPoint?

    /// Whether spot metering is active — the reticle shows only then.
    var isSpotActive: Bool

    /// Called with a normalized point when the photographer taps to place a spot,
    /// so spot metering is actually *drivable* under the harness and not just
    /// visible. Defaults to doing nothing for the previews below.
    var onPlaceSpot: (CGPoint) -> Void = { _ in }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                sceneBody(in: geometry.size)
                grain
                if isSpotActive {
                    StandInReticle()
                        .position(
                            x: (spot?.x ?? 0.5) * geometry.size.width,
                            y: (spot?.y ?? 0.5) * geometry.size.height
                        )
                }
            }
            // Only spot metering places a spot, mirroring the shipped preview's
            // coordinator: a stray tap in average mode must not switch the mode.
            .contentShape(Rectangle())
            .onTapGesture { location in
                guard isSpotActive else { return }
                onPlaceSpot(
                    CGPoint(
                        x: location.x / geometry.size.width,
                        y: location.y / geometry.size.height
                    )
                )
            }
        }
        .background(.black)
        .ignoresSafeArea()
    }

    @ViewBuilder private func sceneBody(in size: CGSize) -> some View {
        switch scene {
        case .blownSky: blownSky(in: size)
        case .dimInterior: dimInterior
        case .mixedContrast: mixedContrast(in: size)
        }
    }

    // MARK: - Scenes

    /// Sky graduating from a deep zenith blue down to white haze at the horizon,
    /// with a blown-out sun, over a dark treeline.
    ///
    /// The ridge is sized so only its peaks reach above the portrait drawer: most
    /// of the HUD sits over the brightest part of the frame — the case it has to
    /// survive — while the near-black treeline still cuts across the drawer's own
    /// surface, so one glass element spans the scene's whole range at once.
    private func blownSky(in size: CGSize) -> some View {
        ZStack(alignment: .bottom) {
            LinearGradient(
                colors: [
                    Color(red: 0.33, green: 0.53, blue: 0.85),
                    Color(red: 0.68, green: 0.81, blue: 0.94),
                    Color(white: 0.97),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            // The sun: a clipped highlight the surrounding sky washes out into.
            RadialGradient(
                colors: [.white, .white.opacity(0)],
                center: UnitPoint(x: 0.72, y: 0.24),
                startRadius: 0,
                endRadius: max(size.width, size.height) * 0.42
            )
            // Horizon: a dark treeline the sky burns out against.
            LinearGradient(
                colors: [Color(white: 0.05), Color(white: 0.13)],
                startPoint: .bottom,
                endPoint: .top
            )
            .frame(height: size.height * 0.36)
            .mask(Ridgeline())
        }
    }

    /// A near-black room with a single warm lamp pool low and leading — almost
    /// all shadow, which is where a dark HUD surface risks vanishing into the
    /// scene behind it.
    private var dimInterior: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.07, green: 0.06, blue: 0.05), .black],
                startPoint: .topTrailing,
                endPoint: .bottomLeading
            )
            RadialGradient(
                colors: [
                    Color(red: 1.0, green: 0.78, blue: 0.45).opacity(0.85),
                    Color(red: 0.5, green: 0.3, blue: 0.12).opacity(0.35),
                    .clear,
                ],
                center: UnitPoint(x: 0.24, y: 0.68),
                startRadius: 0,
                endRadius: 300
            )
            // A second, far dimmer bounce so the shadows aren't a flat fill.
            RadialGradient(
                colors: [Color(red: 0.3, green: 0.34, blue: 0.42).opacity(0.30), .clear],
                center: UnitPoint(x: 0.85, y: 0.12),
                startRadius: 0,
                endRadius: 260
            )
        }
    }

    /// A dark interior wall with a blown window in it: the hard bright/dark edge
    /// the HUD's translucent surfaces are most likely to break on.
    ///
    /// The window is placed so its lower half falls behind the portrait drawer —
    /// the drawer's surface has to carry near-white and near-black at once, which
    /// is the failure a scene that is uniformly bright or uniformly dark hides.
    private func mixedContrast(in size: CGSize) -> some View {
        ZStack {
            LinearGradient(
                colors: [Color(white: 0.09), Color(white: 0.02)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            // Light spilling out of the window across the near wall — under the
            // window itself, so it softens the wall without lifting the pane.
            RadialGradient(
                colors: [Color(red: 0.62, green: 0.66, blue: 0.75).opacity(0.42), .clear],
                center: UnitPoint(x: 0.56, y: 0.55),
                startRadius: size.width * 0.2,
                endRadius: size.width * 1.1
            )
            // The window: a hard-edged near-white rectangle with a daylight cast,
            // mullioned so the bright/dark boundary isn't one straight edge.
            windowPane
                .frame(width: size.width * 0.58, height: size.height * 0.46)
                .position(x: size.width * 0.56, y: size.height * 0.60)
        }
    }

    private var windowPane: some View {
        ZStack {
            LinearGradient(
                colors: [
                    .white,
                    Color(red: 0.93, green: 0.95, blue: 1.0),
                    Color(red: 0.78, green: 0.85, blue: 0.95),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            // Mullions, in the dark of the wall they interrupt.
            Rectangle().fill(Color(white: 0.04)).frame(width: 7)
            Rectangle().fill(Color(white: 0.04)).frame(height: 7)
        }
        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
    }

    // MARK: - Grain

    /// A faint deterministic grain over the whole frame.
    ///
    /// Every drawn gradient is perfectly smooth, and smooth gradients are exactly
    /// what a refracting surface has nothing to bite on. The grain gives the
    /// backdrop the fine luminance noise a real frame has. Seeded, so two runs of
    /// the same scene produce the same pixels and two screenshots stay
    /// comparable.
    private var grain: some View {
        Canvas { context, size in
            var seed: UInt64 = 0x5EED
            func next() -> Double {
                // xorshift64: tiny, deterministic, and no dependency on the
                // platform's RNG (which would move between runs).
                seed ^= seed << 13
                seed ^= seed >> 7
                seed ^= seed << 17
                return Double(seed % 10_000) / 10_000
            }
            for _ in 0..<2_600 {
                let rect = CGRect(
                    x: next() * size.width,
                    y: next() * size.height,
                    width: 1.5,
                    height: 1.5
                )
                context.fill(
                    Path(ellipseIn: rect),
                    with: .color(.white.opacity(next() * 0.10))
                )
            }
        }
        .blendMode(.overlay)
        .allowsHitTesting(false)
    }
}

/// The blown-sky horizon: a couple of overlapping hills, drawn from fixed
/// fractions of the band so the silhouette is the same on every run and at every
/// screen size. The crest deliberately clears the portrait drawer's top edge, so
/// the drawer's surface is asked to carry both the treeline and the sky.
private struct Ridgeline: Shape {
    func path(in rect: CGRect) -> Path {
        let width = rect.width
        let height = rect.height
        var path = Path()

        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - height * 0.42))
        path.addCurve(
            to: CGPoint(x: rect.minX + width * 0.44, y: rect.minY + height * 0.04),
            control1: CGPoint(x: rect.minX + width * 0.14, y: rect.maxY - height * 0.72),
            control2: CGPoint(x: rect.minX + width * 0.28, y: rect.minY)
        )
        path.addCurve(
            to: CGPoint(x: rect.maxX, y: rect.maxY - height * 0.55),
            control1: CGPoint(x: rect.minX + width * 0.62, y: rect.minY + height * 0.22),
            control2: CGPoint(x: rect.minX + width * 0.84, y: rect.maxY - height * 0.88)
        )
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

/// The harness' approximation of the spot reticle: the shipped circle, redrawn in
/// SwiftUI. Every dimension comes from the same `ReticleGeometry` the UIKit one
/// strokes, so it exists to make spot mode inspectable in the Simulator without
/// becoming a second opinion about what the reticle looks like.
private struct StandInReticle: View {
    var body: some View {
        Circle()
            .strokeBorder(
                Color.white.opacity(ReticleGeometry.rimOpacity),
                lineWidth: ReticleGeometry.rimWidth
            )
            .frame(width: ReticleGeometry.diameter, height: ReticleGeometry.diameter)
            .overlay {
                Circle()
                    .fill(Color.appAccent)
                    .frame(
                        width: ReticleGeometry.dotRadius * 2,
                        height: ReticleGeometry.dotRadius * 2
                    )
            }
            // The same shadow the shipped rim carries, for the same reason: a
            // white hairline vanishes against a blown-out sky.
            .shadow(color: .black.opacity(0.6), radius: 3)
            .allowsHitTesting(false)
    }
}

#Preview("Blown sky") {
    StandInSceneView(scene: .blownSky, isSpotActive: false)
}

#Preview("Dim interior") {
    StandInSceneView(scene: .dimInterior, isSpotActive: false)
}

#Preview("Mixed contrast") {
    StandInSceneView(scene: .mixedContrast, isSpotActive: false)
}
#endif
