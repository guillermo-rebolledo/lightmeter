import SwiftUI

@main
struct LightmeterApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView(source: Self.injectedLightSource)
                .preferredColorScheme(.dark)
        }
    }

    /// The light source the meter is driven by, resolved **once** at app start:
    /// `nil` for the real camera, or the design harness' stand-in when this debug
    /// build was launched with `-design-harness`.
    ///
    /// `static let` is the once-only parse — the launch arguments are read the
    /// first time the scene is built and never again. In a Release build the
    /// harness does not exist and this is unconditionally `nil`, which is
    /// `ContentView`'s own default.
    private static let injectedLightSource: LightSource? = {
        #if DEBUG
        DesignHarness.makeLightSource()
        #else
        nil
        #endif
    }()
}
