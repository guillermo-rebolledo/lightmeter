import Testing
@testable import Lightmeter

/// The launch-argument contract for *meter state* — the half of the harness that
/// decides what the screen is showing rather than what it is looking at.
///
/// A screenshot is only evidence if the state it shows was chosen. These tests
/// pin the two halves of that: the parse (a launch argument becomes a named
/// state) and the drive (that state, pushed through the view-model's own entry
/// points, actually lands). The advisory cases go further and assert the
/// *engine's* real output, because "forced present" means the warning is on
/// screen, not that a flag was set somewhere.
@MainActor
struct DesignHarnessMeterStateTests {
    /// Waits for `predicate` to hold, yielding to let the metering task run.
    /// Fails as "never became true" rather than as a confusing downstream `nil`.
    private func waitUntil(
        _ predicate: () -> Bool,
        sourceLocation: SourceLocation = #_sourceLocation
    ) async {
        for _ in 0..<10_000 {
            if predicate() { return }
            await Task.yield()
        }
        Issue.record("Condition never became true", sourceLocation: sourceLocation)
    }

    /// Launches a view-model under `arguments` exactly the way the app does, and
    /// runs `body` once it has settled — metered, or knowingly still pending.
    private func withHarnessedModel(
        _ arguments: [String],
        _ body: (MeterViewModel, DesignHarnessConfiguration) async -> Void
    ) async {
        let configuration = DesignHarnessConfiguration.parse(
            launchArguments: ["-design-harness"] + arguments
        )
        guard let configuration else {
            Issue.record("The harness did not parse")
            return
        }

        // The app's own order: start metering, then push the launch state in.
        // Applying before the first reading is the real sequencing the harness
        // has to survive, so don't quietly wait first.
        let model = MeterViewModel(source: DesignHarness.makeLightSource(for: configuration))
        await model.start()
        await configuration.state.apply(to: model)
        if configuration.isPending == false {
            await waitUntil { model.ev != nil }
        }

        await body(model, configuration)

        model.stop()
    }

    // MARK: - Defaults

    /// An unqualified `-design-harness` has to reproduce the ordinary screen: the
    /// baseline shots were taken that way, and every named state is judged as a
    /// deviation from it.
    @Test func defaultsMatchTheViewModelsOwnOpeningState() async {
        let state = DesignHarnessConfiguration.parse(launchArguments: ["-design-harness"])?.state

        #expect(state?.mode == .aperturePriority)
        #expect(state?.pattern == .average)
        #expect(state?.compensation == 0)
        #expect(state?.isFrozen == false)
        // No preset, so the view-model keeps its own legs rather than the harness
        // freezing today's defaults into every screenshot.
        #expect(state?.legs == nil)
        #expect(
            DesignHarnessConfiguration.parse(launchArguments: ["-design-harness"])?.isPending
                == false
        )
    }

    // MARK: - Priority mode

    @Test func priorityModeIsChosenByLaunchArgument() async {
        let cases: [(String, PriorityMode)] = [
            ("aperture", .aperturePriority),
            ("shutter", .shutterPriority),
        ]

        for (argument, expected) in cases {
            await withHarnessedModel(["-harness-priority", argument]) { model, configuration in
                #expect(configuration.state.mode == expected)
                #expect(model.mode == expected)
                // The solved leg is what the mode is for, so pin it too: an
                // agent naming "shutter-priority" is asking to see the aperture
                // read AUTO.
                #expect(model.triangle.solved == expected.solvedComponent)
            }
        }
    }

    @Test func anUnparseablePriorityFallsBackToTheDefault() {
        let state = DesignHarnessConfiguration.parse(
            launchArguments: ["-design-harness", "-harness-priority", "nonsense"]
        )?.state

        #expect(state?.mode == .aperturePriority)
    }

    // MARK: - Metering pattern

    @Test func meteringPatternIsChosenByLaunchArgument() async {
        await withHarnessedModel(["-harness-pattern", "spot"]) { model, configuration in
            #expect(configuration.state.pattern == .spot)
            #expect(model.pattern == .spot)
            // Spot with nowhere placed defaults to the frame center, so the
            // reticle is always somewhere a screenshot can show it.
            #expect(model.spot == .frameCenter)
        }

        await withHarnessedModel(["-harness-pattern", "average"]) { model, _ in
            #expect(model.pattern == .average)
        }
    }

    @Test func anUnparseablePatternFallsBackToTheDefault() {
        let state = DesignHarnessConfiguration.parse(
            launchArguments: ["-design-harness", "-harness-pattern", "nonsense"]
        )?.state

        #expect(state?.pattern == .average)
    }

    // MARK: - Compensation

    @Test func compensationIsChosenByLaunchArgument() async {
        await withHarnessedModel(["-harness-compensation", "1.0"]) { model, _ in
            #expect(model.compensation == 1.0)
            #expect(model.compensationLabel == "+1.0 EV")
        }

        await withHarnessedModel(["-harness-compensation", "-2.0"]) { model, _ in
            #expect(model.compensation == -2.0)
        }
    }

    /// The clamp lives in `setCompensation`, and the harness goes through it
    /// rather than around it — an out-of-range argument lands on the same value a
    /// photographer dialling to the end of the control would see.
    @Test func compensationIsClampedByTheViewModelsOwnEntryPoint() async {
        await withHarnessedModel(["-harness-compensation", "9"]) { model, _ in
            #expect(model.compensation == 3)
        }
    }

    // MARK: - Frozen / live

    @Test func theMeterIsLiveUnlessTheLaunchArgumentFreezesIt() async {
        await withHarnessedModel([]) { model, _ in
            #expect(model.isFrozen == false)
        }
    }

    @Test func frozenIsChosenByLaunchArgument() async {
        await withHarnessedModel(["-harness-frozen"]) { model, configuration in
            #expect(configuration.state.isFrozen)
            #expect(model.isFrozen)
            // Frozen means a reading is being *held* — a frozen screen with no
            // reading is the pending state wearing the wrong label.
            #expect(model.ev != nil)
        }
    }

    // MARK: - Pending

    /// The state before the first reading lands: metering, with nothing to show
    /// yet. It exists for a fraction of a second on a phone, which is exactly why
    /// it is otherwise impossible to screenshot deliberately.
    @Test func theStateBeforeAnyReadingIsReachable() async {
        await withHarnessedModel(["-harness-pending"]) { model, configuration in
            #expect(configuration.isPending)
            #expect(model.status == .metering)
            #expect(model.latestReading == nil)
            #expect(model.ev == nil)
            #expect(model.triangle.marking(of: model.triangle.solved) == nil)
            #expect(model.advisories.isEmpty)
        }
    }

    /// Nothing has arrived to hold, so the freeze is dropped at parse rather than
    /// left to hang the launch waiting for a reading that never comes.
    @Test func pendingWinsOverFrozen() async {
        let configuration = DesignHarnessConfiguration.parse(
            launchArguments: ["-design-harness", "-harness-pending", "-harness-frozen"]
        )

        #expect(configuration?.isPending == true)
        #expect(configuration?.state.isFrozen == false)
    }

    // MARK: - Advisories

    /// The whole point of the presets: each names a warning and the meter shows
    /// exactly that one, out of the *real* engine. If the engine's thresholds
    /// move, these fail rather than the screenshots quietly becoming wrong.
    @Test func advisoryPresetsForceExactlyTheNamedAdvisory() async {
        let cases: [(String, [ExposureAdvisory])] = [
            ("none", []),
            ("handheld", [.handheldRisk]),
            ("tripod", [.tripodRecommended]),
            ("out-of-range", [.outsideTypicalRange(.shutter)]),
        ]

        for (argument, expected) in cases {
            await withHarnessedModel(["-harness-advisory", argument]) { model, _ in
                #expect(model.advisories == expected, "for -harness-advisory \(argument)")
            }
        }
    }

    /// The out-of-range advisory is the one warning both modes can raise, so it
    /// has to be reachable in the mode the agent asked for rather than silently
    /// dragging the screen back to aperture-priority.
    @Test func theOutOfRangeAdvisoryIsReachableInEitherMode() async {
        let cases: [(String, PriorityMode, ExposureAdvisory)] = [
            ("aperture", .aperturePriority, .outsideTypicalRange(.shutter)),
            ("shutter", .shutterPriority, .outsideTypicalRange(.aperture)),
        ]

        for (priority, mode, advisory) in cases {
            await withHarnessedModel([
                "-harness-advisory", "out-of-range", "-harness-priority", priority,
            ]) { model, _ in
                #expect(model.mode == mode)
                #expect(model.advisories == [advisory])
            }
        }
    }

    /// Handholding warnings only exist where the shutter is solved, so asking for
    /// one asks for aperture-priority — better than honouring the mode and
    /// showing a screen with no warning on it at all.
    @Test func shutterAdvisoriesForceTheModeThatCanRaiseThem() async {
        for argument in ["handheld", "tripod"] {
            await withHarnessedModel([
                "-harness-advisory", argument, "-harness-priority", "shutter",
            ]) { model, _ in
                #expect(model.mode == .aperturePriority, "for -harness-advisory \(argument)")
                #expect(model.advisories.isEmpty == false)
            }
        }
    }

    /// A preset pins the light as well as the legs — it cannot promise a warning
    /// otherwise — so it has the last word over a scene's own EV.
    @Test func anAdvisoryPresetOverridesTheScenesLight() {
        let configuration = DesignHarnessConfiguration.parse(
            launchArguments: [
                "-design-harness", "-harness-scene", "blown-sky",
                "-harness-advisory", "tripod", "-harness-ev", "15",
            ]
        )

        // The backdrop is still the one that was asked for; only the light the
        // meter reads is pinned.
        #expect(configuration?.scene == .blownSky)
        #expect(configuration?.sceneEV != StandInScene.blownSky.nominalEV)
        #expect(configuration?.state.legs != nil)
    }

    /// Absent the option, advisories are whatever the scene and the legs happen
    /// to produce — the baseline screenshots stay untouched.
    @Test func withoutAPresetTheAdvisoriesAreWhateverTheSceneProduces() {
        let configuration = DesignHarnessConfiguration.parse(
            launchArguments: ["-design-harness", "-harness-scene", "dim-interior"]
        )

        #expect(configuration?.sceneEV == StandInScene.dimInterior.nominalEV)
        #expect(configuration?.state.legs == nil)
    }

    @Test func anUnparseableAdvisoryLeavesTheAdvisoriesAlone() {
        let configuration = DesignHarnessConfiguration.parse(
            launchArguments: ["-design-harness", "-harness-advisory", "nonsense"]
        )

        #expect(configuration?.state.legs == nil)
        #expect(configuration?.sceneEV == StandInScene.blownSky.nominalEV)
    }

    // MARK: - Combined

    /// The state the ticket is named for, in one command: shutter-priority, spot
    /// metering, +1 EV, frozen. Combining the options has to compose rather than
    /// have the last one win.
    @Test func theOptionsCompose() async {
        await withHarnessedModel([
            "-harness-scene", "mixed-contrast",
            "-harness-priority", "shutter",
            "-harness-pattern", "spot",
            "-harness-compensation", "1.0",
            "-harness-frozen",
        ]) { model, configuration in
            #expect(configuration.scene == .mixedContrast)
            #expect(model.mode == .shutterPriority)
            #expect(model.pattern == .spot)
            #expect(model.compensation == 1.0)
            #expect(model.isFrozen)
        }
    }
}
