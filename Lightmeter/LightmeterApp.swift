import SwiftUI

@main
struct LightmeterApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                // Dark, camera-app baseline for the whole app.
                .preferredColorScheme(.dark)
        }
    }
}
