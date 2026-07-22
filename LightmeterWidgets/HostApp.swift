//
//  HostApp.swift
//  LightmeterWidgets
//

import Foundation

/// Facts about the host app, read from its bundle so the control tracks a rename.
enum HostApp {
    /// The host app's user-facing name.
    ///
    /// The extension runs from `<App>.app/PlugIns/…​.appex`, so walking two levels
    /// up from our own bundle lands on the enclosing `.app`; reading its display
    /// name there means a future app rename flows through with no app group.
    /// Falls back through `CFBundleDisplayName` → `CFBundleName` → a literal.
    static var displayName: String {
        let appBundleURL = Bundle.main.bundleURL
            .deletingLastPathComponent()  // PlugIns
            .deletingLastPathComponent()  // <App>.app
        let appBundle = Bundle(url: appBundleURL) ?? .main
        return appBundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? appBundle.object(forInfoDictionaryKey: "CFBundleName") as? String
            ?? "Lightmeter"
    }
}
