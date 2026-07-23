import SwiftUI

/// Liquid Glass, with a mandatory pre-iOS-26 fallback.
///
/// Per the standing project rule, the `.ultraThinMaterial` + accent-tint styling
/// is the *primary* design and Liquid Glass is the enhancement layered on top for
/// iOS 26. Every helper here therefore carries a complete, intentional fallback —
/// the pre-26 branch is never empty or broken. The glass path is gated behind
/// `if #available(iOS 26, *)` in one place per surface so the call sites stay flat.
///
/// The interactive surfaces (freeze padlock, the top-left status pills, exposure
/// chips, settings gear) each get a purpose-built modifier below; the shared
/// `MeterHUDCard` groups its glass with `glassGroup()` so adjacent elements blend
/// inside a single `GlassEffectContainer`. Because portrait and landscape compose
/// the *same* control instances, applying these here changes both orientations at
/// once.

/// The app's accent, matched to the `.tint(.appAccent)` applied at the container
/// level so a glass `tint(_:)` and the fallback's `.tint` shape style read the
/// same colour. Reads from the single ``Color/appAccent`` token.
private let glassAccent: Color = .appAccent

extension View {
    /// Wraps the receiver in a `GlassEffectContainer` on iOS 26 so its glass and
    /// any descendant glass blend as one system; a no-op passthrough on the
    /// fallback, where the material surfaces stand on their own.
    @ViewBuilder
    func glassGroup() -> some View {
        if #available(iOS 26, *) {
            GlassEffectContainer { self }
        } else {
            self
        }
    }
}

/// A capsule control surface — the top-left status pills and the controls they
/// reveal. iOS 26: interactive Liquid Glass, accent-tinted while active. Pre-26:
/// the tint/white capsule fill with an accent ring — the established look.
struct GlassPillBackground: ViewModifier {
    /// Whether the control is in its active/selected state (the pill whose editor
    /// is open): a brighter tint and a full ring on both paths.
    let isActive: Bool

    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content.glassEffect(
                .regular.tint(isActive ? glassAccent : nil).interactive(),
                in: .capsule
            )
        } else {
            content
                .background(
                    isActive ? AnyShapeStyle(.tint.opacity(0.22)) : AnyShapeStyle(.white.opacity(0.08)),
                    in: Capsule()
                )
                .overlay(
                    Capsule()
                        .strokeBorder(.tint.opacity(isActive ? 0.8 : 0), lineWidth: 1)
                )
        }
    }
}

/// The freeze padlock's surface: a circular control beside the hero. iOS 26:
/// interactive Liquid Glass in a circle. Pre-26: the same white-on-glass fill the
/// chips use — the established look, complete on its own.
///
/// The held state rides on an accent ring rather than an accent fill, borrowing
/// the chips' selection-ring vocabulary: the padlock glyph is already accent, and
/// tinting the fill underneath it would put accent on accent. Like the chip ring
/// it is a stroke inside the control's own bounds, so freezing costs no layout.
struct GlassLockBackground: ViewModifier {
    /// Whether the reading is held — the closed-padlock state, ringed.
    let isHeld: Bool

    func body(content: Content) -> some View {
        surface(content)
            .overlay(
                Circle().strokeBorder(.tint.opacity(isHeld ? 0.9 : 0), lineWidth: 1.5)
            )
    }

    @ViewBuilder private func surface(_ content: Content) -> some View {
        if #available(iOS 26, *) {
            content.glassEffect(.regular.interactive(), in: .circle)
        } else {
            content.background(.white.opacity(0.08), in: .circle)
        }
    }
}

/// An exposure-triangle chip surface. All three chips share one identical base
/// surface — clear Liquid Glass on iOS 26, white-on-glass on the fallback — so the
/// row reads as a single control rather than three differently-weighted fills.
/// State rides on top as a single consistent cue: the dial-bound leg gets an
/// accent ring (the "selected" marker). The held and solved legs are distinguished
/// by their padlock and text treatment (set in `ExposureChipsView`), not by a
/// different fill, so the held / solved / plain hierarchy stays legible without
/// breaking the shared look. The ring is a stroke inside the chip's own bounds, so
/// it costs no layout and moving the dial never reflows the row.
struct GlassChipBackground: ViewModifier {
    /// The chip the ruler dial is bound to — the only state that changes the
    /// surface, via an accent selection ring.
    let isBound: Bool

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
    }

    func body(content: Content) -> some View {
        surface(content)
            .overlay(
                shape.strokeBorder(.tint.opacity(isBound ? 0.9 : 0), lineWidth: 1.5)
            )
    }

    @ViewBuilder private func surface(_ content: Content) -> some View {
        if #available(iOS 26, *) {
            content.glassEffect(.regular, in: shape)
        } else {
            content.background(.white.opacity(0.08), in: shape)
        }
    }
}

/// Which screen edge the HUD drawer docks to. Sets the two-corner rounded shape
/// (the inner corners are rounded, the ones on the screen edge are square), the
/// safe areas the surface bleeds past, and the stretch axis.
enum DrawerEdge {
    /// Portrait: the drawer rises from the bottom, full-width, its top two corners
    /// rounded; the surface bleeds down behind the home indicator.
    case bottom
    /// Landscape: the drawer slides in from the trailing edge, full-height, its two
    /// leading (inner) corners rounded; the surface bleeds out to the physical edge.
    case trailing
}

extension View {
    /// Docks the receiver as the HUD drawer against `edge`: stretches it along the
    /// screen edge, groups the glass *controls* it holds (the freeze padlock and
    /// the chips) into one `GlassEffectContainer` via `glassGroup()` so adjacent
    /// glass blends as a single system, then lays the two-corner `GlassCardBackground`
    /// surface behind the whole group (which bleeds to the physical edge while the
    /// content stays inside the safe area). Shared by both layouts so the docking
    /// recipe lives in one place even though the stretch axis differs per edge.
    ///
    /// The surface is applied **outside** the container on purpose: a full-bleed
    /// `glassEffect` surface *inside* the same container frosts the only two rows
    /// that carry no glass pill of their own — the hero EV readout and the advisory
    /// line — rendering them behind the drawer's own glass. Keeping the surface a
    /// plain background behind the grouped content lets that content stay crisp on
    /// top while the controls still blend among themselves.
    func docked(edge: DrawerEdge) -> some View {
        drawerStretch(edge: edge)
            .glassGroup()
            .modifier(GlassCardBackground(edge: edge))
    }

    /// Stretches the drawer along the screen edge it docks to: full-width at the
    /// bottom, full-height (content top-aligned) at the trailing edge. The
    /// cross-axis extent is left to the content (its natural height in portrait, a
    /// fixed width set by the layout in landscape).
    @ViewBuilder
    private func drawerStretch(edge: DrawerEdge) -> some View {
        switch edge {
        case .bottom: frame(maxWidth: .infinity)
        case .trailing: frame(maxHeight: .infinity, alignment: .top)
        }
    }
}

/// The docked HUD drawer surface. iOS 26: clear Liquid Glass in the drawer's
/// two-corner rounded shape. Pre-26: the dialled-back `.ultraThinMaterial` that
/// lets more of the preview show through. The surface bleeds all the way to the
/// physical screen edge (behind the home indicator in portrait, out past the
/// trailing safe area in landscape) via `ignoresSafeArea`, while the drawer content
/// stays inside the safe area so it never collides with the home indicator, notch,
/// or Dynamic Island.
///
/// A darkening scrim sits *behind the drawer content but in front of the glass /
/// material* on both paths, so the white / `.secondary` / `.yellow` HUD text keeps
/// its contrast even over a blown-out sky where the translucent surface alone would
/// wash out. It is gated the same way the glass is: a light scrim under iOS 26
/// Liquid Glass — enough to guarantee legibility while preserving the refracting
/// look — and a denser scrim on the `.ultraThinMaterial` fallback so it reads as a
/// stable dark surface. Both branches stay complete and intentional per the
/// standing fallback rule.
struct GlassCardBackground: ViewModifier {
    /// The edge the drawer docks to — its two inner corners are rounded, the two on
    /// the screen edge are square.
    let edge: DrawerEdge

    /// The inner corner radius, applied to the two corners that face the content.
    private static let cornerRadius: CGFloat = 24
    /// Tuned to hold text legibility over bright scenes without flattening the
    /// glass's refraction; the fallback leans darker since its material carries
    /// less depth of its own.
    private static let glassScrimOpacity = 0.28
    private static let fallbackScrimOpacity = 0.32

    /// The two-corner shape: the inner corners rounded at 24pt, the edge corners
    /// square, so the surface can sit flush against the screen edge.
    private var shape: UnevenRoundedRectangle {
        let r = Self.cornerRadius
        switch edge {
        case .bottom:
            // Top two corners rounded (the drawer rises from the bottom).
            return UnevenRoundedRectangle(
                topLeadingRadius: r, bottomLeadingRadius: 0,
                bottomTrailingRadius: 0, topTrailingRadius: r,
                style: .continuous
            )
        case .trailing:
            // The two leading corners rounded (the drawer enters from the right).
            return UnevenRoundedRectangle(
                topLeadingRadius: r, bottomLeadingRadius: r,
                bottomTrailingRadius: 0, topTrailingRadius: 0,
                style: .continuous
            )
        }
    }

    /// The safe areas the surface bleeds past to reach the physical screen edges —
    /// only the edges the drawer is docked against, so the rounded inner corners
    /// stay anchored at the content boundary.
    private var bleedEdges: Edge.Set {
        switch edge {
        case .bottom: [.bottom]
        case .trailing: [.trailing, .top, .bottom]
        }
    }

    func body(content: Content) -> some View {
        content.background { surface.ignoresSafeArea(edges: bleedEdges) }
    }

    /// The scrim-over-surface stack, drawn behind the content so the order
    /// front-to-back is content → scrim → glass / material.
    ///
    /// The scrim is composited **in front of** the glass / material (an overlay on
    /// iOS 26, an overlay on the fallback material) rather than tinted underneath
    /// it: Liquid Glass refracts the bright preview above the drawer's inner edge,
    /// and a scrim tinted *under* the glass is overpowered right where the hero EV
    /// readout and the advisory line sit — the two rows that carry no glass pill of
    /// their own. A gentle gradient adds extra darkening at that inner edge, fading
    /// toward the screen edge so the glass still reads on the lower rows.
    @ViewBuilder private var surface: some View {
        if #available(iOS 26, *) {
            shape
                .glassEffect(.regular, in: shape)
                .overlay { scrim }
        } else {
            shape.fill(.ultraThinMaterial).opacity(0.82)
                .overlay { scrim }
        }
    }

    /// The legibility scrim: a base level plus a boost at the drawer's inner
    /// (rounded-corner) edge, where the glass pulls in the bright scene.
    private var scrim: some View {
        LinearGradient(
            colors: [
                .black.opacity(scrimOpacity + 0.16),
                .black.opacity(scrimOpacity),
            ],
            startPoint: scrimStart,
            endPoint: scrimEnd
        )
        .clipShape(shape)
    }

    /// The base scrim opacity for the active surface path.
    private var scrimOpacity: CGFloat {
        if #available(iOS 26, *) { Self.glassScrimOpacity } else { Self.fallbackScrimOpacity }
    }

    /// The gradient runs from the drawer's inner (content-facing, rounded) edge —
    /// darkest, where the glass refracts the bright scene — toward the screen edge.
    private var scrimStart: UnitPoint {
        switch edge {
        case .bottom: .top
        case .trailing: .leading
        }
    }

    private var scrimEnd: UnitPoint {
        switch edge {
        case .bottom: .bottom
        case .trailing: .trailing
        }
    }
}

/// The settings gear surface. iOS 26: a small Liquid Glass circle in its own
/// `GlassEffectContainer`. Pre-26: the bare tinted icon it has always been —
/// intentional and complete without a material behind it.
struct GlassCircleBackground: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            GlassEffectContainer {
                content.glassEffect(.regular.interactive(), in: .circle)
            }
        } else {
            content
        }
    }
}
