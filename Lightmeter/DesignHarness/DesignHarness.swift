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
    /// An advisory preset overrides it: a warning cannot be promised without
    /// pinning the light that raises it.
    var sceneEV: Double

    /// Whether the meter is held before its first reading — the state the screen
    /// is in for a fraction of a second on a phone, and otherwise impossible to
    /// screenshot on purpose. Metering starts as usual; nothing ever arrives.
    var isPending: Bool

    /// What the screen is showing: mode, pattern, bias, freeze.
    var state: DesignHarnessMeterState

    /// The flag that turns the harness on. Nothing else here has any effect
    /// without it, so a stray `-harness-ev` in a scheme can't quietly fake the
    /// meter during ordinary debugging.
    private static let enableFlag = "-design-harness"
    private static let sceneOption = "-harness-scene"
    private static let sceneEVOption = "-harness-ev"
    private static let priorityOption = "-harness-priority"
    private static let patternOption = "-harness-pattern"
    private static let compensationOption = "-harness-compensation"
    private static let advisoryOption = "-harness-advisory"
    private static let frozenFlag = "-harness-frozen"
    private static let pendingFlag = "-harness-pending"

    /// Reads the harness' configuration out of a process' launch arguments, or
    /// `nil` when the harness was not asked for.
    ///
    /// Takes the arguments rather than reading `ProcessInfo` so the contract is
    /// testable without launching anything.
    static func parse(launchArguments: [String]) -> DesignHarnessConfiguration? {
        guard launchArguments.contains(enableFlag) else { return nil }

        let scene = value(of: sceneOption, in: launchArguments)
            .flatMap(StandInScene.init(rawValue:)) ?? .blownSky
        let requestedMode = value(of: priorityOption, in: launchArguments)
            .flatMap(PriorityMode.init(harnessArgument:)) ?? DesignHarnessMeterState.opening.mode
        let advisory = value(of: advisoryOption, in: launchArguments)
            .flatMap(DesignHarnessAdvisoryPreset.init(rawValue:)) ?? .auto
        // The preset has the last word on the light and the legs: it is a promise
        // about what is on screen, and it cannot keep that promise while another
        // argument moves the solve out from under it.
        let recipe = advisory.recipe(requestedMode: requestedMode)

        let sceneEV = recipe?.sceneEV
            ?? value(of: sceneEVOption, in: launchArguments).flatMap(Double.init)
            ?? scene.nominalEV
        let isPending = launchArguments.contains(pendingFlag)

        let state = DesignHarnessMeterState(
            mode: recipe?.mode ?? requestedMode,
            pattern: value(of: patternOption, in: launchArguments)
                .flatMap(MeteringPattern.init(harnessArgument:))
                ?? DesignHarnessMeterState.opening.pattern,
            compensation: value(of: compensationOption, in: launchArguments)
                .flatMap(Double.init) ?? DesignHarnessMeterState.opening.compensation,
            // A pending meter has no reading to hold, so the two are not
            // combinable; resolving it here keeps the launch from waiting on a
            // reading that is never coming.
            isFrozen: launchArguments.contains(frozenFlag) && isPending == false,
            legs: recipe?.legs
        )

        return DesignHarnessConfiguration(
            scene: scene,
            sceneEV: sceneEV,
            isPending: isPending,
            state: state
        )
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

// MARK: - Launch-argument spellings
//
// Kept here rather than on the production enums: the harness is the only thing
// that needs a string form of these, and a Release build has no business
// carrying one.

extension PriorityMode {
    /// The mode named on the command line, by the leg it holds fixed.
    init?(harnessArgument: String) {
        switch harnessArgument {
        case "aperture": self = .aperturePriority
        case "shutter": self = .shutterPriority
        default: return nil
        }
    }
}

extension MeteringPattern {
    /// The pattern named on the command line.
    init?(harnessArgument: String) {
        switch harnessArgument {
        case "average": self = .average
        case "spot": self = .spot
        default: return nil
        }
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
        configuration.map(makeLightSource(for:))
    }

    /// The source a given configuration asks for. Split out from the launch-time
    /// entry point above so a test can drive a configuration it built itself,
    /// rather than the one this process happened to launch with.
    static func makeLightSource(for configuration: DesignHarnessConfiguration) -> LightSource {
        ScriptedLightSource(
            sceneEV: configuration.sceneEV,
            // A pending launch meters exactly as usual and simply never receives
            // anything — which is what the state *is*, rather than a fourth
            // status invented to stand for it.
            emitsReadings: configuration.isPending == false
        )
    }

    /// Drives a freshly-started meter to the state this launch asked for, or does
    /// nothing at all on an ordinary run.
    ///
    /// Called once, right after `MeterViewModel.start()`. Everything it does goes
    /// through the view-model's own entry points, so the harness cannot reach a
    /// state the UI could not.
    @MainActor
    static func applyLaunchState(to model: MeterViewModel) async {
        await configuration?.state.apply(to: model)
    }

    /// The scene to draw where there is no capture device.
    ///
    /// Falls back to the same scene `DesignHarnessConfiguration.parse` defaults
    /// to, so a backdrop drawn without a parsed configuration (a SwiftUI preview,
    /// a test) is the one the harness would have chosen anyway rather than an
    /// arbitrary third answer.
    static var backdropScene: StandInScene {
        configuration?.scene ?? .blownSky
    }

    // MARK: - Forcing the pre-iOS-26 fallback

    /// The flag that forces ``LiquidGlass/isEnabled`` off, so every glass surface
    /// in the app renders its pre-iOS-26 fallback on an OS that has glass.
    ///
    /// Deliberately **not** behind `-design-harness`: the fallback is worth
    /// looking at over the real camera on a device as well as over a stand-in
    /// scene in the Simulator, and pairing the two flags is what produces the
    /// side-by-side reference shots.
    static let forceGlassFallbackFlag = "-force-glass-fallback"

    /// Whether this launch asked for the fallback rendering. Resolved once, at
    /// first touch, so the gate cannot flip mid-session and leave half the
    /// screen on each path.
    static let forcesGlassFallback = forcesGlassFallback(
        launchArguments: ProcessInfo.processInfo.arguments
    )

    /// The parse, split from the launch-time constant above so the contract is
    /// testable without launching anything.
    static func forcesGlassFallback(launchArguments: [String]) -> Bool {
        launchArguments.contains(forceGlassFallbackFlag)
    }
}
#endif
