#if DEBUG
import Foundation

// MARK: - Design harness: meter state (DEBUG only)
//
// #92 made the meter screen *reachable* in the Simulator. This is the other half:
// making a chosen state reachable, so a screenshot shows what it was meant to
// show rather than whatever the app happened to open on.
//
// Everything here goes through `MeterViewModel`'s own entry points — `setMode`,
// `setPattern`, `setCompensation`, `toggleFreeze`, the leg setters. The harness
// has no privileged access and adds no state of its own: whatever it produces,
// a photographer could have produced by tapping. That is what keeps a harness
// screenshot admissible as evidence about the real screen.

/// A warning the harness can put on screen on purpose.
///
/// Advisories are *derived* — the engine raises them from the solve, and there
/// is no setter to force one. So a preset works the way a photographer would:
/// it picks a light level and a set of legs whose honest solve lands in the band
/// that raises the named warning. The values are pinned by test against the real
/// engine, so a moved threshold breaks a test rather than a screenshot.
enum DesignHarnessAdvisoryPreset: String, CaseIterable {
    /// Leave advisories to whatever the scene and legs produce (the default).
    case auto

    /// A comfortably handholdable solve — the deliberately *empty* advisory row.
    /// Named `none` on the command line; spelled `clear` here to stay clear of
    /// `Optional.none` at every call site.
    case clear = "none"

    /// The soft warning: slower than 1/60 s, faster than 1/15 s.
    case handheld

    /// The strong warning: 1/15 s or slower.
    case tripod

    /// The solved leg falls off the end of its scale — the state the shipped
    /// range check exists for, and the one that never happens on demand.
    case outsideRange = "out-of-range"
}

/// The light and the legs a preset pins in order to guarantee its advisory.
struct DesignHarnessAdvisoryRecipe: Equatable {
    /// The mode the advisory can be raised in — see `recipe(requestedMode:)`.
    var mode: PriorityMode
    /// The scene EV@ISO 100 the meter must read for the solve to land in band.
    var sceneEV: Double
    /// The legs the solve is computed from.
    var legs: DesignHarnessLegs
}

/// The three legs, as the photographer's inputs. Only an advisory preset sets
/// them; otherwise the view-model keeps its own opening values.
struct DesignHarnessLegs: Equatable {
    var iso: Double
    var aperture: Double
    var shutter: Double
}

extension DesignHarnessAdvisoryPreset {
    /// The recipe that forces this preset's advisory, or `nil` for `.auto` —
    /// which pins nothing and leaves the scene's own light and the view-model's
    /// own legs alone.
    ///
    /// `requestedMode` is honoured where it can be. Handholding warnings only
    /// exist where the shutter is the solved leg, so asking for one in
    /// shutter-priority asks for something that cannot exist; the mode gives way
    /// rather than the warning, because a screen with neither is no use to
    /// anyone. The out-of-range check runs in both modes and keeps the mode it
    /// was given.
    ///
    /// Every EV below is `t = N² / 2^EV` at ISO 100 (and its aperture-priority
    /// mirror), chosen to sit in the middle of its band rather than on a
    /// threshold, so a rounding change doesn't flip the screen to a different
    /// warning.
    func recipe(requestedMode: PriorityMode) -> DesignHarnessAdvisoryRecipe? {
        switch self {
        case .auto:
            return nil

        case .clear:
            switch requestedMode {
            case .aperturePriority:
                // f/8 at EV 15 → 1/512 s: fast, and well inside the scale.
                return recipe(mode: .aperturePriority, sceneEV: 15, aperture: 8)
            case .shutterPriority:
                // 1/125 s at EV 12 → ~f/5.7: mid-scale, nothing to warn about.
                return recipe(mode: .shutterPriority, sceneEV: 12, shutter: 1.0 / 125)
            }

        case .handheld:
            // f/8 at EV 11 → 1/32 s: between the 1/60 s and 1/15 s thresholds.
            return recipe(mode: .aperturePriority, sceneEV: 11, aperture: 8)

        case .tripod:
            // f/8 at EV 6 → 1 s: far past 1/15 s, still on the scale.
            return recipe(mode: .aperturePriority, sceneEV: 6, aperture: 8)

        case .outsideRange:
            switch requestedMode {
            case .aperturePriority:
                // f/8 at EV 22 → ~1/65000 s, off the fast end of 1/8000 s–30 s.
                return recipe(mode: .aperturePriority, sceneEV: 22, aperture: 8)
            case .shutterPriority:
                // 1/125 s at EV 0 → ~f/0.09, off the wide end of f/1.0–f/32.
                return recipe(mode: .shutterPriority, sceneEV: 0, shutter: 1.0 / 125)
            }
        }
    }

    /// A recipe at ISO 100, with the leg the mode does not fix left at the
    /// view-model's own default so only the leg that matters is being pinned.
    private func recipe(
        mode: PriorityMode,
        sceneEV: Double,
        aperture: Double = 8,
        shutter: Double = 1.0 / 125
    ) -> DesignHarnessAdvisoryRecipe {
        DesignHarnessAdvisoryRecipe(
            mode: mode,
            sceneEV: sceneEV,
            legs: DesignHarnessLegs(iso: 100, aperture: aperture, shutter: shutter)
        )
    }
}

/// The meter state a harness launch asks for: everything about what the screen
/// is *showing*, as opposed to what it is looking at (the scene and its light,
/// which live on ``DesignHarnessConfiguration``).
struct DesignHarnessMeterState: Equatable {
    /// Which leg the photographer holds and which the meter solves.
    var mode: PriorityMode

    /// Whole-frame average, or a spot. A spot with nowhere placed lands at the
    /// frame center — the view-model's own fallback — so the reticle is always
    /// somewhere a screenshot can show it.
    var pattern: MeteringPattern

    /// Deliberate exposure bias in stops, clamped on the way in by the
    /// view-model's own ±3 range.
    var compensation: Double

    /// Whether the reading is held. Applied *after* a reading arrives, because
    /// there is nothing to hold before then.
    var isFrozen: Bool

    /// The legs an advisory preset pinned, or `nil` to leave the view-model's
    /// own. Left alone by default so the harness doesn't freeze today's defaults
    /// into every screenshot taken from now on.
    var legs: DesignHarnessLegs?

    /// The state an unqualified `-design-harness` launch gets: the view-model's
    /// own opening state, so the baseline shots stay reproducible. Restated here
    /// rather than read off a view-model, because the parse is not on the main
    /// actor; `defaultsMatchTheViewModelsOwnOpeningState` holds the two together.
    ///
    /// Not `live` — "live" already means *not frozen* on this screen.
    static let opening = DesignHarnessMeterState(
        mode: .aperturePriority,
        pattern: .average,
        compensation: 0,
        isFrozen: false,
        legs: nil
    )

    /// Drives a freshly-started view-model to this state through its own public
    /// entry points, in the order a photographer would: set the mode (which
    /// re-binds the dial), then the legs it governs, then the pattern, then the
    /// bias — and only then the freeze, which needs something to hold.
    ///
    /// Call once, right after `start()`. Returns when the state has landed,
    /// which for a frozen launch means after the first reading has been held —
    /// so a screenshot taken on return is a screenshot of the asked-for state.
    @MainActor
    func apply(to model: MeterViewModel) async {
        model.setMode(mode)
        if let legs {
            model.setISO(legs.iso)
            model.setAperture(legs.aperture)
            model.setShutter(legs.shutter)
        }
        model.setPattern(pattern)
        model.setCompensation(compensation)

        guard isFrozen else { return }
        await Self.waitForFirstReading(of: model)
        // A no-op if nothing ever arrived — the view-model already refuses to
        // freeze an empty meter, and the harness doesn't get to override that.
        model.toggleFreeze()
    }

    /// Polls until the meter has a reading to hold, or gives up.
    ///
    /// Polling rather than observing: the alternative is an `withObservationTracking`
    /// dance around a value that flips exactly once, a few hundred milliseconds
    /// into a debug-only launch. The bound matters more than the latency — a
    /// source that never emits (a pending launch, a wedged one) must not hang the
    /// app on its first frame.
    @MainActor
    private static func waitForFirstReading(of model: MeterViewModel) async {
        for _ in 0..<pollLimit {
            if model.latestReading != nil { return }
            try? await Task.sleep(for: pollInterval)
        }
    }

    /// ~2 s of patience, in 20 ms steps: comfortably longer than the stand-in
    /// source's first emission, comfortably shorter than a screenshot script's
    /// own settle.
    private static let pollInterval = Duration.milliseconds(20)
    private static let pollLimit = 100
}
#endif
