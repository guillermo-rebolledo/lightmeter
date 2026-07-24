//
//  LightmeterWidgetsControl.swift
//  LightmeterWidgets
//

import AppIntents
import SwiftUI
import WidgetKit

/// The launcher control: one tap opens Lightmeter into its live meter.
///
/// On iOS 18 a single control serves both Control Center and the Lock Screen
/// corner buttons. Its label tracks the host app's display name so a future
/// rename carries through automatically, and its tint reads the app's single
/// accent token — the file is compiled into this extension as well as the app —
/// so the control the photographer taps is already wearing the colour of the
/// screen it opens.
struct LauncherControl: ControlWidget {
    static let kind = "dev.gortiz.Lightmeter.Widgets.Launcher"

    var body: some ControlWidgetConfiguration {
        let appName = HostApp.displayName
        return StaticControlConfiguration(kind: Self.kind) {
            ControlWidgetButton(action: LaunchLightmeterIntent()) {
                Label(appName, systemImage: "camera.aperture")
            }
            .tint(Color.appAccent)
        }
        .displayName("\(appName)")
        .description("Opens the live meter.")
    }
}
