import Foundation
import SwiftUI
import Testing
@testable import Lightmeter

/// The design tokens, made enforceable.
///
/// The accent and the numeric face are app-wide by construction: there is one
/// definition of each, and everything that draws accented or numeric reads from
/// it. That claim is only true for as long as nothing quietly names a colour or a
/// font of its own — so, in the same shape as `LiquidGlassFallbackTests`'
/// one-gate sweep, these tests read the shipping sources back and fail on the
/// drift rather than trusting a convention.
struct DesignTokensTests {
    // MARK: - The accent

    /// The handoff's muted brass gold, `#E7B85C`. System yellow reads as a
    /// warning colour on a screen whose job includes warning; brass reads as
    /// brass.
    @Test func theAccentIsTheHandoffsBrassGold() throws {
        let components = try channels(of: UIColor.appAccent)

        #expect(abs(components.red - 231.0 / 255) < 0.001)
        #expect(abs(components.green - 184.0 / 255) < 0.001)
        #expect(abs(components.blue - 92.0 / 255) < 0.001)
        #expect(abs(components.alpha - 1) < 0.001)
    }

    /// Both asset catalogs' `AccentColor` mirror the token.
    ///
    /// They exist because the OS — not our code — draws with them: the app icon's
    /// tint, and any system chrome that resolves the global accent before a
    /// `.tint(.appAccent)` reaches it. A catalog is data, so nothing about it
    /// *derives* from the token; this is what keeps the mirror honest, and it
    /// covers the widget extension's catalog, which no runtime lookup from the
    /// app's test bundle could reach.
    @Test(arguments: [
        "Lightmeter/Assets.xcassets/AccentColor.colorset/Contents.json",
        "LightmeterWidgets/Assets.xcassets/AccentColor.colorset/Contents.json",
    ])
    func theAssetCatalogsAccentMirrorsTheToken(_ relativePath: String) throws {
        let token = try channels(of: UIColor.appAccent)
        let entries = try assetColorComponents(atRepositoryPath: relativePath)

        // Every appearance, not just the first: the app is dark throughout, so a
        // light/dark split here would be a second accent hiding in the catalog.
        #expect(entries.isEmpty == false, "\(relativePath) declares no colours")
        for entry in entries {
            #expect(abs(entry.red - token.red) < 0.002, "\(relativePath) red drifted")
            #expect(abs(entry.green - token.green) < 0.002, "\(relativePath) green drifted")
            #expect(abs(entry.blue - token.blue) < 0.002, "\(relativePath) blue drifted")
        }
    }

    /// No surface names an accent of its own. The token is the only source, so
    /// re-theming stays the one-line change it is advertised as — and the yellow
    /// this replaced cannot survive in a corner nobody re-screenshotted.
    @Test func noSurfaceNamesAnAccentColourOfItsOwn() throws {
        try ShippingSources.expectAbsent(
            Self.accentImpostors,
            exceptIn: Self.accentTokenPath,
            reason: "read Color.appAccent instead"
        )
    }

    // MARK: - The numeric face

    /// The rounded face is gone. It was the meter's voice before the handoff, and
    /// a leftover `design: .rounded` is a readout that did not come along.
    @Test func theRoundedFaceIsGone() throws {
        try ShippingSources.expectAbsent(
            ["design: .rounded", "withDesign(.rounded)"],
            reason: "the meter's face is the one AppTypography declares"
        )
    }

    /// Numerals are *declared*, not patched. `.monospacedDigit()` widens the
    /// digits of a proportional face and leaves everything else — the slash in
    /// "1/125", the "f/" — proportional; a monospaced face holds the whole
    /// string's rhythm. Only the token file may name the face, so a new readout
    /// cannot reach for the half-measure.
    @Test func numeralsGoThroughTheTokenRatherThanPatchingDigits() throws {
        try ShippingSources.expectAbsent(
            ["monospacedDigit", "design: .monospaced", "monospacedSystemFont"],
            exceptIn: Self.typographyTokenPath,
            reason: "declare the numeral through AppTypography instead"
        )
    }

    // MARK: - The tiers

    /// The floor, raised from the handoff's 9pt: 9pt uppercase tracked gold on
    /// glass, over a live scene, is not readable. `.caption2` is exactly 11pt at
    /// the default text size, which is the smallest tier anything uses.
    @Test func theLabelFloorIsElevenPoints() {
        #expect(AppTypography.labelFloorPointSize == 11)
    }

    /// …and nothing sets a smaller size behind the floor's back. Point sizes are
    /// only ever written for the fixed tiers — the large numerals and the couple
    /// of glyphs — so a literal below the floor is a tier that escaped it.
    @Test func nothingIsSetSmallerThanTheLabelFloor() throws {
        for file in try ShippingSources.all() {
            let text = try String(contentsOf: URL(fileURLWithPath: file), encoding: .utf8)
            for size in try Self.pointSizes(in: text) {
                #expect(
                    size >= AppTypography.labelFloorPointSize,
                    "\(file) sets \(size)pt, below the \(AppTypography.labelFloorPointSize)pt floor"
                )
            }
        }
    }

    /// Where Dynamic Type stops growing the meter's small tiers. Past this the
    /// HUD has no room left to give, and scale-to-fit takes over from growth —
    /// the split the handoff asked for, in one place rather than per readout.
    @Test func theDynamicTypeCeilingIsAccessibility3() {
        #expect(AppTypography.maximumDynamicTypeSize == .accessibility3)
    }

    // MARK: - Reading the sources back

    /// Colours that would be a second accent — the yellow this replaced.
    ///
    /// Deliberately broad in one direction: matching the bare `.yellow` catches
    /// `Color.yellow` and `UIColor.yellow` alike, and prose that merely *names*
    /// the old accent trips it too, because a comment saying "yellow" in a view
    /// is a comment describing a decision that view no longer makes.
    ///
    /// Deliberately narrow in the other: orange is *not* banned. #76's superseded
    /// orange accent is dead, but orange is also a colour a warning could
    /// legitimately want one day, and the accent's single-source guarantee is
    /// already carried by the catalog-mirror test above rather than by a
    /// blocklist.
    private static let accentImpostors = [".yellow", "systemYellow"]

    private static let accentTokenPath = "Lightmeter/AppAccent.swift"
    private static let typographyTokenPath = "Lightmeter/AppTypography.swift"

    /// Every explicit point size in `text` — `size:`, `ofSize:`, and the token's
    /// own `fixedSize:`.
    ///
    /// Matched on the `size:` suffix rather than on a word boundary: `\b` cannot
    /// match between the `d` and the `S` of `fixedSize`, so a leading-boundary
    /// pattern would skip the one spelling this app writes most — leaving the
    /// floor unenforced exactly where the tokens are declared.
    private static func pointSizes(in text: String) throws -> [CGFloat] {
        let pattern = try Regex(#"[Ss]ize: (\d+(?:\.\d+)?)\b"#)
        return try text.matches(of: pattern).map { match in
            let digits = try #require(match[1].substring, "unmatched capture group")
            return CGFloat(try #require(Double(digits)))
        }
    }

    /// The sRGB channels of a catalog colorset at `relativePath`, one entry per
    /// declared appearance. Read from the checkout rather than the built bundle so
    /// the widget extension's catalog is reachable too.
    private func assetColorComponents(
        atRepositoryPath relativePath: String
    ) throws -> [(red: CGFloat, green: CGFloat, blue: CGFloat)] {
        let url = ShippingSources.repositoryRoot.appending(path: relativePath)
        let data = try Data(contentsOf: url)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let colors = try #require(json?["colors"] as? [[String: Any]], "no colours at \(relativePath)")

        return try colors.map { entry in
            let color = try #require(entry["color"] as? [String: Any])
            #expect(color["color-space"] as? String == "srgb", "\(relativePath) is not sRGB")
            let components = try #require(color["components"] as? [String: String])
            let channels = try ["red", "green", "blue"].map { name -> CGFloat in
                let text = try #require(components[name], "\(relativePath) has no \(name)")
                return CGFloat(try #require(Double(text), "\(relativePath) \(name) is not a number"))
            }
            return (channels[0], channels[1], channels[2])
        }
    }

    private func channels(
        of color: UIColor
    ) throws -> (red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat) {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        try #require(color.getRed(&red, green: &green, blue: &blue, alpha: &alpha))
        return (red, green, blue, alpha)
    }
}
