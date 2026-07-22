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
/// rename carries through automatically.
struct LauncherControl: ControlWidget {
    static let kind = "dev.gortiz.Lightmeter.Widgets.Launcher"

    var body: some ControlWidgetConfiguration {
        let appName = HostApp.displayName
        return StaticControlConfiguration(kind: Self.kind) {
            ControlWidgetButton(action: LaunchLightmeterIntent()) {
                Label(appName, systemImage: "camera.aperture")
            }
            .tint(Color("AccentColor"))
        }
        .displayName("\(appName)")
        .description("Opens the live meter.")
    }
}
