import SwiftUI

/// Liquid Glass, with a mandatory pre-iOS-26 fallback.
///
/// Per the standing project rule, the `.ultraThinMaterial` + accent-tint styling
/// is the *primary* design and Liquid Glass is the enhancement layered on top for
/// iOS 26. Every helper here therefore carries a complete, intentional fallback —
/// the pre-26 branch is never empty or broken. The glass path is gated behind
/// `if #available(iOS 26, *)` in one place per surface so the call sites stay flat.
///
/// The interactive surfaces (freeze button, control-strip buttons, exposure
/// chips, settings gear) each get a purpose-built modifier below; the shared
/// `MeterHUDCard` groups its glass with `glassGroup()` so adjacent elements blend
/// inside a single `GlassEffectContainer`. Because portrait and landscape compose
/// the *same* control instances, applying these here changes both orientations at
/// once.

/// The app's accent, matched to the `.tint(.yellow)` applied at the container
/// level so a glass `tint(_:)` and the fallback's `.tint` shape style read the
/// same colour.
private let glassAccent: Color = .yellow

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

/// A capsule control surface — the freeze icon button and the control-strip icon
/// buttons. iOS 26: interactive Liquid Glass, accent-tinted while active. Pre-26:
/// the tint/white capsule fill with an accent ring — the established look.
struct GlassPillBackground: ViewModifier {
    /// Whether the control is in its active/selected state (frozen, or the open
    /// strip section): a brighter tint and a full ring on both paths.
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

/// An exposure-triangle chip surface. All three chips share one identical base
/// surface — clear Liquid Glass on iOS 26, white-on-glass on the fallback — so the
/// row reads as a single control rather than three differently-weighted fills.
/// State rides on top as a single consistent cue: the dial-bound leg gets an
/// accent ring (the "selected" marker). The solved leg is distinguished by its
/// accent value text (set in `ExposureChipsView`), not by a different fill, so the
/// set / bound / solved hierarchy stays legible without breaking the shared look.
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

/// The compact HUD card surface. iOS 26: clear Liquid Glass in the card's rounded
/// rectangle. Pre-26: the dialled-back `.ultraThinMaterial` that lets more of the
/// preview show through.
///
/// A darkening scrim sits *behind the card content but in front of the glass /
/// material* on both paths, so the white / `.secondary` / `.yellow` HUD text keeps
/// its contrast even over a blown-out sky where the translucent surface alone would
/// wash out. It is gated the same way the glass is: a light scrim under iOS 26
/// Liquid Glass — enough to guarantee legibility while preserving the refracting
/// look — and a denser scrim on the `.ultraThinMaterial` fallback so it reads as a
/// stable dark surface. Both branches stay complete and intentional per the
/// standing fallback rule.
struct GlassCardBackground: ViewModifier {
    /// Tuned to hold text legibility over bright scenes without flattening the
    /// glass's refraction; the fallback leans darker since its material carries
    /// less depth of its own.
    private static let glassScrimOpacity = 0.16
    private static let fallbackScrimOpacity = 0.32

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
    }

    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content
                // Scrim behind the content, above the glass: `.background` layers
                // it under the content, and `.glassEffect` then renders beneath
                // that — so the order front-to-back is content → scrim → glass.
                .background { shape.fill(.black.opacity(Self.glassScrimOpacity)) }
                .glassEffect(.regular, in: shape)
        } else {
            content.background {
                shape.fill(.ultraThinMaterial).opacity(0.82)
                    .overlay { shape.fill(.black.opacity(Self.fallbackScrimOpacity)) }
            }
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
