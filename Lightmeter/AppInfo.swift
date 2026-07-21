import Foundation

/// Lightweight, dependency-free facts about the app.
/// Kept trivial on purpose so the smoke test has something real to assert against.
enum AppInfo {
    /// User-facing app name, shown on the placeholder screen.
    static let name = "Lightmeter"

    /// One-line tagline for the placeholder / about surfaces.
    static let tagline = "Reflected light meter"
}
