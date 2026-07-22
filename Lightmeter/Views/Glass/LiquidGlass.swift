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

/// An exposure-triangle chip surface. iOS 26: Liquid Glass, prominently
/// accent-tinted for the bound leg, a softer tint for the solved leg, clear for a
/// plain set leg. Pre-26: the tint-wash / bright-fill / white-on-glass fills. The
/// accent ring rides on top of both paths so the bound and solved rings survive.
struct GlassChipBackground: ViewModifier {
    let isSolved: Bool
    let isBound: Bool

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
    }

    func body(content: Content) -> some View {
        surface(content)
            .overlay(
                shape.strokeBorder(.tint.opacity(strokeOpacity), lineWidth: isBound ? 1.5 : 1)
            )
    }

    @ViewBuilder private func surface(_ content: Content) -> some View {
        if #available(iOS 26, *) {
            content.glassEffect(glass, in: shape)
        } else {
            content.background(fillStyle, in: shape)
        }
    }

    @available(iOS 26, *)
    private var glass: Glass {
        if isBound { return .regular.tint(glassAccent) }
        if isSolved { return .regular.tint(glassAccent.opacity(0.5)) }
        return .regular
    }

    private var fillStyle: AnyShapeStyle {
        if isSolved { return AnyShapeStyle(.tint.opacity(0.16)) }
        if isBound { return AnyShapeStyle(.tint.opacity(0.22)) }
        return AnyShapeStyle(.white.opacity(0.08))
    }

    private var strokeOpacity: Double {
        if isBound { return 0.9 }
        if isSolved { return 0.55 }
        return 0
    }
}

/// The compact HUD card surface. iOS 26: clear Liquid Glass in the card's rounded
/// rectangle. Pre-26: the dialled-back `.ultraThinMaterial` that lets more of the
/// preview show through.
struct GlassCardBackground: ViewModifier {
    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
    }

    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content.glassEffect(.regular, in: shape)
        } else {
            content.background {
                shape.fill(.ultraThinMaterial).opacity(0.82)
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
