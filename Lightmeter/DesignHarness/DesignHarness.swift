#if DEBUG
import Foundation

// MARK: - Design harness (DEBUG only)
//
// The Simulator has no capture device, so `CameraLightSource` never produces a
// reading and the meter screen lands on `.unavailable` — every design iteration
// otherwise has to be built to a phone. The harness removes that block: with a
// launch argument, the meter is driven by a `ScriptedLightSource` at a scene EV
// chosen on the command line, over a `StandInScene` drawn behind the UI in place
// of the camera preview.
//
// Everything in this directory is wrapped in `#if DEBUG` at file scope, so a
// Release build compiles none of it — the harness cannot ship even by accident.
// The only production-code concession is `ContentView`'s optional injection
// points, which are `nil` in Release and leave behaviour exactly as it was.

/// How the design harness is configured for this launch.
///
/// The presence of `-design-harness` is what turns the harness on; the remaining
/// options only refine it. Every value has a fallback, because a mistyped
/// argument should still give a running screen to look at rather than a launch
/// that dies or a meter stuck on "unavailable".
struct DesignHarnessConfiguration: Equatable {
    /// The scene drawn behind the UI, standing in for the camera preview.
    var scene: StandInScene

    /// The scene's EV@ISO 100 — what the meter reads. Defaults to the chosen
    /// scene's own light, so naming a scene is enough to see the HUD under it.
    var sceneEV: Double

    /// The flag that turns the harness on. Nothing else here has any effect
    /// without it, so a stray `-harness-ev` in a scheme can't quietly fake the
    /// meter during ordinary debugging.
    private static let enableFlag = "-design-harness"
    private static let sceneOption = "-harness-scene"
    private static let sceneEVOption = "-harness-ev"

    /// Reads the harness' configuration out of a process' launch arguments, or
    /// `nil` when the harness was not asked for.
    ///
    /// Takes the arguments rather than reading `ProcessInfo` so the contract is
    /// testable without launching anything.
    static func parse(launchArguments: [String]) -> DesignHarnessConfiguration? {
        guard launchArguments.contains(enableFlag) else { return nil }

        let scene = value(of: sceneOption, in: launchArguments)
            .flatMap(StandInScene.init(rawValue:)) ?? .blownSky
        let sceneEV = value(of: sceneEVOption, in: launchArguments)
            .flatMap(Double.init) ?? scene.nominalEV

        return DesignHarnessConfiguration(scene: scene, sceneEV: sceneEV)
    }

    /// The argument following `option`, or `nil` when the option is absent or is
    /// the last argument (so there is nothing to read as its value).
    private static func value(of option: String, in arguments: [String]) -> String? {
        guard let index = arguments.firstIndex(of: option) else { return nil }
        let valueIndex = arguments.index(after: index)
        guard valueIndex < arguments.endIndex else { return nil }
        return arguments[valueIndex]
    }
}

/// The app's single entry point into the harness, resolved **once** at launch.
///
/// `static let` gives the one-shot parse: the arguments are read the first time
/// `configuration` is touched (at app start) and never again, so nothing later in
/// the session can flip the app into or out of harness mode.
enum DesignHarness {
    /// This launch's harness configuration, or `nil` for an ordinary run.
    static let configuration = DesignHarnessConfiguration.parse(
        launchArguments: ProcessInfo.processInfo.arguments
    )

    /// The light source the meter should be driven by, or `nil` to use the real
    /// camera. Each call vends a fresh source; the app makes exactly one.
    static func makeLightSource() -> LightSource? {
        configuration.map { ScriptedLightSource(sceneEV: $0.sceneEV) }
    }
}
#endif
