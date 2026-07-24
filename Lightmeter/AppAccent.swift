import SwiftUI

/// The app's single accent token — the sole source of the app-wide tint.
///
/// `#E7B85C`, the design handoff's muted brass gold. It replaces system yellow,
/// which was always a placeholder: yellow is the platform's *warning* colour, and
/// this is a screen that genuinely warns — blown highlights, camera shake, a leg
/// off the end of its scale. An accent that already means "careful" cannot also
/// mean "this is the instrument". Brass reads as brass.
///
/// Everything that used to reach for `.yellow` on its own (the container `.tint`,
/// the Liquid Glass `glassAccent`, the spot reticle, the launcher control) reads
/// from here, so re-theming the app stays the one-line change it advertises.
/// `DesignTokensTests.noSurfaceNamesAnAccentColourOfItsOwn` is what keeps that
/// true; the asset catalogs' `AccentColor` — which the OS, not our code, draws
/// with — mirror this value, checked by the same suite.
extension Color {
    static let appAccent = Color(red: 231 / 255, green: 184 / 255, blue: 92 / 255)
}

extension UIColor {
    /// The UIKit mirror of ``Color/appAccent``, derived from the same token so
    /// the SwiftUI tint and the CoreAnimation reticle can never drift apart.
    static let appAccent = UIColor(Color.appAccent)
}
