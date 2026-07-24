import SwiftUI

/// Liquid Glass, with a mandatory pre-iOS-26 fallback.
///
/// Per the standing project rule, the `.ultraThinMaterial` + accent-tint styling
/// is the *primary* design and Liquid Glass is the enhancement layered on top for
/// iOS 26. Every surface here therefore carries a complete, intentional fallback —
/// the pre-26 branch is never empty or broken.
///
/// The whole file hangs off **one decision**: ``LiquidGlass/isEnabled``. Every
/// surface is described as data (``GlassSurface``) and rendered by a single
/// `glassSurface(_:)` helper that asks the gate once; no other file in the app
/// mentions iOS 26, `glassEffect`, or `GlassEffectContainer`. That is what makes
/// the fallback *forceable* — flip the one gate and every surface in the app takes
/// its fallback path at once (see `docs/design-harness.md`).
///
/// The interactive surfaces (freeze padlock, the top-left status pills, exposure
/// chips, settings gear) each get a purpose-built modifier below; the shared
/// `MeterHUDCard` groups its glass with `glassGroup()` so adjacent elements blend
/// inside a single `GlassEffectContainer`. Because portrait and landscape compose
/// the *same* control instances, applying these here changes both orientations at
/// once.

// MARK: - The gate

/// The app's single Liquid Glass decision.
///
/// Ask this — never `#available(iOS 26, *)` — anywhere the design differs between
/// the glass path and its fallback. Collapsing the branching to one question is
/// what lets a debug launch argument force every surface onto its fallback at
/// once, so the rule that "every glass surface ships a complete fallback" is
/// checkable rather than aspirational.
enum LiquidGlass {
    /// Whether this run renders Liquid Glass rather than the fallback design.
    ///
    /// `false` below iOS 26 — there is no glass to render — and `false` on iOS 26
    /// when a debug launch has forced the fallback on.
    static var isEnabled: Bool {
        guard #available(iOS 26, *) else { return false }
        return isForcedOff == false
    }

    /// Whether this launch asked to be shown the fallback on an OS that has
    /// glass. Debug-only: a Release build compiles the constant `false` here, so
    /// the shipped app has no way to reach the forced path.
    private static var isForcedOff: Bool {
        #if DEBUG
        DesignHarness.forcesGlassFallback
        #else
        false
        #endif
    }
}

// MARK: - The surfaces

/// Every Liquid Glass surface in the app, as data.
///
/// A case per surface rather than a modifier per surface, so all of them can be
/// rendered from the one place that asks the gate. Payloads are only the state
/// that changes the *surface*; shapes and metrics are derived here so a case is
/// cheap to construct and easy to enumerate in a test.
enum GlassSurface: Equatable {
    /// A container whose descendants' glass blends as one system.
    case group

    /// A capsule control surface — the top-left status pills.
    /// `isActive` is the pill whose editor is open.
    case pill(isActive: Bool)

    /// The freeze padlock's circular surface.
    case lock

    /// An exposure-triangle chip surface.
    case chip

    /// The settings gear's surface.
    case settingsGear

    /// The docked HUD drawer's full-bleed surface, including its legibility
    /// scrim. Unlike the others it draws a surface of its own rather than
    /// backing the receiver's content; the receiver supplies only the frame.
    case drawer(edge: DrawerEdge)

    /// The chip surface's shape, shared with the selection ring drawn over it.
    static let chipShape = RoundedRectangle(cornerRadius: 14, style: .continuous)

    /// Which surface this is, ignoring the state it carries.
    ///
    /// The associated values rule out `CaseIterable`, so this stands in for it:
    /// a new case cannot compile without landing here, and
    /// `allCoversEverySurface` then fails until it is in ``all`` — which is what
    /// keeps a new surface from being silently untested.
    var kind: Kind {
        switch self {
        case .group: .group
        case .pill: .pill
        case .lock: .lock
        case .chip: .chip
        case .settingsGear: .settingsGear
        case .drawer: .drawer
        }
    }

    /// The surfaces, stripped of their state.
    enum Kind: CaseIterable {
        case group, pill, lock, chip, settingsGear, drawer
    }

    /// At least one value per case — every state that changes the surface, and
    /// every edge the drawer docks to. The tests walk this list, and
    /// `allCoversEverySurface` holds it to ``Kind``.
    static let all: [GlassSurface] = [
        .group,
        .pill(isActive: false),
        .pill(isActive: true),
        .lock,
        .chip,
        .settingsGear,
        .drawer(edge: .bottom),
        .drawer(edge: .trailing),
    ]
}

/// The app's accent, matched to the `.tint(.appAccent)` applied at the container
/// level so a glass `tint(_:)` and the fallback's `.tint` shape style read the
/// same colour. Reads from the single ``Color/appAccent`` token.
private let glassAccent: Color = .appAccent

extension View {
    /// Renders `surface` behind (or around) the receiver, on whichever path the
    /// gate is on.
    ///
    /// **This is the only place in the app that branches on iOS 26.** The
    /// `#available` below is the compiler's ceremony — it is what unlocks the
    /// iOS 26 API — while the decision belongs to ``LiquidGlass/isEnabled``.
    func glassSurface(_ surface: GlassSurface) -> some View {
        glassSurface(surface, isGlassEnabled: LiquidGlass.isEnabled)
    }

    /// The seam under ``glassSurface(_:)``: the same rendering with the gate's
    /// answer passed in rather than read.
    ///
    /// Exists so a test can render either path on demand — the forced fallback is
    /// exercised rather than assumed — without a process-wide switch that the
    /// rest of the app could see.
    @ViewBuilder
    func glassSurface(_ surface: GlassSurface, isGlassEnabled: Bool) -> some View {
        if #available(iOS 26, *), isGlassEnabled {
            glassPath(surface)
        } else {
            fallbackPath(surface)
        }
    }

    /// The iOS 26 rendering of every surface.
    @available(iOS 26, *)
    @ViewBuilder
    private func glassPath(_ surface: GlassSurface) -> some View {
        switch surface {
        case .group:
            GlassEffectContainer { self }

        case .pill(let isActive):
            glassEffect(
                .regular.tint(isActive ? glassAccent : nil).interactive(),
                in: .capsule
            )

        case .lock:
            glassEffect(.regular.interactive(), in: .circle)

        case .chip:
            glassEffect(.regular, in: GlassSurface.chipShape)

        case .settingsGear:
            GlassEffectContainer {
                glassEffect(.regular.interactive(), in: .circle)
            }

        case .drawer(let edge):
            // Clear glass in the drawer's two-corner shape, with the scrim
            // composited in front of it — see `DrawerSurface.scrim`.
            glassEffect(.regular, in: edge.drawerShape)
                .overlay { edge.scrim(opacity: DrawerSurface.glassScrimOpacity) }
        }
    }

    /// The pre-iOS-26 rendering of every surface — the app's primary design, and
    /// what a forced-off gate shows on any OS.
    @ViewBuilder
    private func fallbackPath(_ surface: GlassSurface) -> some View {
        switch surface {
        case .group:
            // No container to join: the material surfaces stand on their own.
            self

        case .pill(let isActive):
            background(
                isActive ? AnyShapeStyle(.tint.opacity(0.22)) : AnyShapeStyle(.white.opacity(0.08)),
                in: Capsule()
            )
            .overlay(
                Capsule().strokeBorder(.tint.opacity(isActive ? 0.8 : 0), lineWidth: 1)
            )

        case .lock:
            // The same white-on-glass fill the chips use — complete on its own.
            background(.white.opacity(0.08), in: .circle)

        case .chip:
            background(.white.opacity(0.08), in: GlassSurface.chipShape)

        case .settingsGear:
            // The bare tinted icon the gear has always been — intentional and
            // complete without a material behind it.
            self

        case .drawer(let edge):
            // The dialled-back `.ultraThinMaterial` that lets more of the preview
            // show through, under a denser scrim than the glass path needs.
            //
            // `hidden()` keeps the receiver's frame and drops its own painting:
            // the material is what fills the shape, and drawing it as a
            // background rather than as the receiver's foreground style keeps
            // that style out of the environment the scrim inherits.
            hidden()
                .background(.ultraThinMaterial, in: edge.drawerShape)
                .opacity(0.82)
                .overlay { edge.scrim(opacity: DrawerSurface.fallbackScrimOpacity) }
        }
    }
}

// MARK: - Control surfaces

extension View {
    /// Wraps the receiver in a `GlassEffectContainer` so its glass and any
    /// descendant glass blend as one system; a no-op passthrough on the fallback,
    /// where the material surfaces stand on their own.
    func glassGroup() -> some View {
        glassSurface(.group)
    }
}

/// The freeze padlock's surface: a circular control beside the hero.
///
/// The held state rides on an accent ring rather than an accent fill, borrowing
/// the chips' selection-ring vocabulary: the padlock glyph is already accent, and
/// tinting the fill underneath it would put accent on accent. Like the chip ring
/// it is a stroke inside the control's own bounds, so freezing costs no layout.
struct GlassLockBackground: ViewModifier {
    /// Whether the reading is held — the closed-padlock state, ringed.
    let isHeld: Bool

    func body(content: Content) -> some View {
        content
            .glassSurface(.lock)
            .overlay(
                Circle().strokeBorder(.tint.opacity(isHeld ? 0.9 : 0), lineWidth: 1.5)
            )
    }
}

/// An exposure-triangle chip surface. All three chips share one identical base
/// surface — clear Liquid Glass on the glass path, white-on-glass on the fallback
/// — so the row reads as a single control rather than three differently-weighted
/// fills. State rides on top as a single consistent cue: the dial-bound leg gets an
/// accent ring (the "selected" marker). The held and solved legs are distinguished
/// by their padlock and text treatment (set in `ExposureChipsView`), not by a
/// different fill, so the held / solved / plain hierarchy stays legible without
/// breaking the shared look. The ring is a stroke inside the chip's own bounds, so
/// it costs no layout and moving the dial never reflows the row.
struct GlassChipBackground: ViewModifier {
    /// The chip the ruler dial is bound to — the only state that changes the
    /// surface, via an accent selection ring.
    let isBound: Bool

    func body(content: Content) -> some View {
        content
            .glassSurface(.chip)
            .overlay(
                GlassSurface.chipShape
                    .strokeBorder(.tint.opacity(isBound ? 0.9 : 0), lineWidth: 1.5)
            )
    }
}

// MARK: - The docked drawer

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
    /// glass surface *inside* the same container frosts the only two rows that
    /// carry no glass pill of their own — the hero EV readout and the advisory
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

/// The docked HUD drawer surface. Glass: clear Liquid Glass in the drawer's
/// two-corner rounded shape. Fallback: the dialled-back `.ultraThinMaterial` that
/// lets more of the preview show through. The surface bleeds all the way to the
/// physical screen edge (behind the home indicator in portrait, out past the
/// trailing safe area in landscape) via `ignoresSafeArea`, while the drawer content
/// stays inside the safe area so it never collides with the home indicator, notch,
/// or Dynamic Island.
///
/// A darkening scrim sits *behind the drawer content but in front of the glass /
/// material* on both paths, so the white / `.secondary` / `.yellow` HUD text keeps
/// its contrast even over a blown-out sky where the translucent surface alone would
/// wash out. It is gated the same way the glass is: a light scrim under Liquid
/// Glass — enough to guarantee legibility while preserving the refracting look —
/// and a denser scrim on the `.ultraThinMaterial` fallback so it reads as a stable
/// dark surface. Both paths stay complete and intentional per the standing
/// fallback rule.
struct GlassCardBackground: ViewModifier {
    /// The edge the drawer docks to — its two inner corners are rounded, the two on
    /// the screen edge are square.
    let edge: DrawerEdge

    func body(content: Content) -> some View {
        content.background {
            edge.drawerShape
                .glassSurface(.drawer(edge: edge))
                .ignoresSafeArea(edges: edge.bleedEdges)
        }
    }
}

/// The drawer surface's shared metrics — the numbers both paths are cut from.
enum DrawerSurface {
    /// The inner corner radius, applied to the two corners that face the content.
    static let cornerRadius: CGFloat = 24
    /// Tuned to hold text legibility over bright scenes without flattening the
    /// glass's refraction; the fallback leans darker since its material carries
    /// less depth of its own.
    static let glassScrimOpacity = 0.28
    static let fallbackScrimOpacity = 0.32
    /// The extra darkening at the drawer's inner edge, where the surface pulls in
    /// the bright scene above it.
    static let scrimEdgeBoost = 0.16
}

extension DrawerEdge {
    /// The two-corner shape: the inner corners rounded at 24pt, the edge corners
    /// square, so the surface can sit flush against the screen edge.
    var drawerShape: UnevenRoundedRectangle {
        let r = DrawerSurface.cornerRadius
        switch self {
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
    var bleedEdges: Edge.Set {
        switch self {
        case .bottom: [.bottom]
        case .trailing: [.trailing, .top, .bottom]
        }
    }

    /// The legibility scrim: a base level plus a boost at the drawer's inner
    /// (rounded-corner) edge, where the surface pulls in the bright scene.
    ///
    /// Composited **in front of** the glass / material rather than tinted
    /// underneath it: Liquid Glass refracts the bright preview above the drawer's
    /// inner edge, and a scrim tinted *under* the glass is overpowered right where
    /// the hero EV readout and the advisory line sit — the two rows that carry no
    /// glass pill of their own.
    func scrim(opacity: CGFloat) -> some View {
        LinearGradient(
            colors: [
                .black.opacity(opacity + DrawerSurface.scrimEdgeBoost),
                .black.opacity(opacity),
            ],
            startPoint: scrimStart,
            endPoint: scrimEnd
        )
        .clipShape(drawerShape)
    }

    /// The gradient runs from the drawer's inner (content-facing, rounded) edge —
    /// darkest, where the surface pulls in the bright scene — toward the screen
    /// edge.
    private var scrimStart: UnitPoint {
        switch self {
        case .bottom: .top
        case .trailing: .leading
        }
    }

    private var scrimEnd: UnitPoint {
        switch self {
        case .bottom: .bottom
        case .trailing: .trailing
        }
    }
}
