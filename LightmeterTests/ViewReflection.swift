import Foundation

/// Reads a SwiftUI view's stored properties by name.
///
/// SwiftUI views are plain structs, so their `let`/`var` inputs (e.g. the
/// `isCompact` flags added across the meter HUD) are visible to `Mirror`
/// regardless of access level — access control is a compile-time-only
/// concept in Swift, not a runtime one. This lets tests assert on a view's
/// stored configuration without needing to render or inspect its `body`,
/// which stays true to how this project tests state rather than rendering.
extension Mirror {
    /// The stored value labeled `name` on `subject`, cast to `T`, or `nil` if
    /// no such stored property exists or the cast fails.
    static func storedValue<T>(_ name: String, on subject: Any) -> T? {
        Mirror(reflecting: subject).children
            .first { $0.label == name }?
            .value as? T
    }
}