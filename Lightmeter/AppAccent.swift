import SwiftUI

/// The app's single accent token — the sole source of the app-wide tint.
///
/// Everything that used to reach for `.yellow` on its own (the container
/// `.tint`, the Liquid Glass `glassAccent`, the spot reticle) now reads from
/// here, so re-theming the app is a one-line change. This portrait usability
/// variant sets the accent to orange; the exact production hex is matched in
/// the final integrate-and-verify ticket.
extension Color {
    static let appAccent = Color.orange
}

extension UIColor {
    /// The UIKit mirror of ``Color/appAccent``, derived from the same token so
    /// the SwiftUI tint and the CoreAnimation reticle can never drift apart.
    static let appAccent = UIColor(Color.appAccent)
}
