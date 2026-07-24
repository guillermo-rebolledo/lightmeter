import SwiftUI

/// Where the meter screen can navigate to. Owned outside `ContentView` because
/// the gear that pushes Settings is now composed in two places — floating over
/// the preview in landscape, and inside the EV headline bar in portrait — and
/// both need to name the same destination.
enum MeterDestination: Hashable {
    case settings
}

/// The settings gear: the meter's one navigation control.
///
/// It has always been owned in *content* space rather than as a `ToolbarItem`, so
/// the guided-tour anchor and the tappable control share one resolved frame, and
/// it has always been a 44pt target around a bare tinted glyph.
///
/// Where it sits is the caller's business — it floats in the top-right corner
/// over the preview in landscape, and rides the trailing end of the EV headline
/// bar in portrait. What changes with that is only whether it carries a surface
/// of its own: floating over the scene it needs one, and on a glass panel that
/// already separates it from the preview, a second glass circle would read as a
/// control stacked on a control rather than as the bar's own chrome.
struct MeterSettingsGear: View {
    /// Whether the gear draws its own glass surface. `false` inside the EV
    /// headline bar, whose panel is already the surface.
    var hasSurface = true

    /// Apple's 44pt minimum, held by the frame rather than by the glyph.
    static let touchTarget: CGFloat = 44

    var body: some View {
        NavigationLink(value: MeterDestination.settings) {
            Label("Settings", systemImage: "gearshape")
                .labelStyle(.iconOnly)
                .foregroundStyle(.tint)
                .frame(width: Self.touchTarget, height: Self.touchTarget)
                .contentShape(Rectangle())
                // On the glass path, a small Liquid Glass circle; on the
                // fallback, the bare tinted icon it has always been — and no
                // surface at all inside the bar, whose panel is already one.
                .glassSurface(.settingsGear, when: hasSurface)
        }
        .buttonStyle(.plain)
        .tint(.appAccent)
        .guidedTourAnchor(.settings)
    }
}
