//
//  LaunchLightmeterIntent.swift
//  LightmeterWidgets
//

import AppIntents

/// Plain-launch intent behind the launcher control.
///
/// Opening the app *is* the entire effect: `openAppWhenRun` brings Lightmeter to
/// the foreground on its live meter, and `perform()` returns immediately. It
/// injects no state, routes nowhere, and unfreezes nothing — the intent lives
/// wholly in the extension, so the app needs no app group, URL scheme, or
/// `onOpenURL` handling.
struct LaunchLightmeterIntent: AppIntent {
    static let title: LocalizedStringResource = "Open Lightmeter"

    /// Bringing the app to the foreground is this intent's only job.
    static let openAppWhenRun = true

    func perform() async throws -> some IntentResult {
        .result()
    }
}
