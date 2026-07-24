import SwiftUI

/// The app's type tokens: one numeric face, one Dynamic Type ceiling, one label
/// floor.
///
/// A light meter is an instrument, and an instrument's numbers hold still. Every
/// numeric readout therefore wears a **monospaced face** rather than a
/// proportional face with `.monospacedDigit()` patched on. The patch only widens
/// the digits: the slash in "1/125", the "f/" in "f/5.6" and the quote in `30"`
/// stay proportional, so a live value still shuffles sideways as it changes — and
/// the screen still reads as an app rather than as a dial. The face fixes the
/// whole string's rhythm.
///
/// `DesignTokensTests` reads the shipping sources back and fails if anything
/// names a face or a size of its own, so this stays the only place either is
/// decided.
enum AppTypography {
    /// The face every number wears.
    private static let numericDesign: Font.Design = .monospaced

    /// A large numeral: the solved-leg hero, and the dial's selected value.
    ///
    /// Fixed rather than relative. These sizes already exceed anything Dynamic
    /// Type would ask for, so growing them buys no legibility and costs the
    /// layout its width — what a large numeral needs from an accessibility size
    /// is to keep *fitting*.
    ///
    /// Which is a call-site question, not this token's: a numeral in a slot it
    /// can outgrow pairs this with
    /// ``SwiftUI/View/scaledToFitOnOneLine(minimumScale:)``, and one with room to
    /// spare — the dial's label, alone above a ruler — does not.
    static func numeral(fixedSize size: CGFloat) -> Font {
        .system(size: size, weight: .semibold, design: numericDesign)
    }

    /// A small numeral — the chip values, the preview's EV label, the
    /// compensation readout, the reticle badge. Relative to `style`, so it grows
    /// with Dynamic Type up to ``maximumDynamicTypeSize``.
    static func numeral(_ style: Font.TextStyle, weight: Font.Weight = .semibold) -> Font {
        .system(style, design: numericDesign, weight: weight)
    }

    /// The UIKit mirror of ``numeral(fixedSize:)``, scaled by the text style it is
    /// quoted against and capped at `maximumPointSize` — the same
    /// hold-past-a-ceiling the SwiftUI side gets from ``maximumDynamicTypeSize``,
    /// spelled the way `UIFontMetrics` spells it.
    static func numeralFont(
        fixedSize size: CGFloat,
        relativeTo style: UIFont.TextStyle,
        maximumPointSize: CGFloat
    ) -> UIFont {
        UIFontMetrics(forTextStyle: style).scaledFont(
            for: .monospacedSystemFont(ofSize: size, weight: .semibold),
            maximumPointSize: maximumPointSize
        )
    }

    /// The smallest tier a label may use — `.caption2`, which is exactly
    /// ``labelFloorPointSize`` at the default text size.
    ///
    /// The handoff specified 9pt for its uppercase tracked captions. 9pt gold on
    /// glass, over a live scene, is not readable; the designer was working in a
    /// frame where 9px looked like about 11pt. The floor is raised to what that
    /// was reaching for.
    static let labelFloorPointSize: CGFloat = 11

    /// Where Dynamic Type stops growing the meter's small tiers.
    ///
    /// Past `accessibility3` the HUD has no room left to give: the card is docked
    /// to an edge and the pills float over a frame the photographer is trying to
    /// see. Size holds here and scale-to-fit takes over — the split the handoff
    /// asked for, declared once for the whole meter screen rather than per
    /// readout.
    static let maximumDynamicTypeSize: DynamicTypeSize = .accessibility3
}

extension View {
    /// Holds the meter's text at ``AppTypography/maximumDynamicTypeSize``.
    ///
    /// Applied once, to the meter screen's root, which is what makes landscape
    /// inherit it without a second implementation. Deliberately *not* applied to
    /// Settings: that is an ordinary scrolling list with room to grow, so it
    /// honours the full range.
    func meterTextScaling() -> some View {
        dynamicTypeSize(...AppTypography.maximumDynamicTypeSize)
    }

    /// One line, shrinking to fit rather than truncating or wrapping.
    ///
    /// The meter's values are already as short as they can be said — "1/8000",
    /// "+1.0 EV" — so a truncated one is a wrong answer, not an abbreviated one.
    func scaledToFitOnOneLine(minimumScale: CGFloat = 0.6) -> some View {
        lineLimit(1).minimumScaleFactor(minimumScale)
    }
}
