import Testing
@testable import Lightmeter

/// The design harness' launch-argument contract.
///
/// This is the seam the whole harness hangs off: the app asks it once at start
/// whether it is being driven by a stand-in scene, and everything else — which
/// light source the meter gets, what is drawn behind the UI — follows from the
/// answer. It is pure string parsing, so it is pinned here rather than discovered
/// by launching a simulator and squinting at a screenshot.
struct DesignHarnessConfigurationTests {
    @Test func absentFlagLeavesTheHarnessOff() {
        #expect(DesignHarnessConfiguration.parse(launchArguments: []) == nil)
        #expect(
            DesignHarnessConfiguration.parse(
                launchArguments: ["/path/to/Lightmeter", "-harness-ev", "15"]
            ) == nil
        )
    }

    @Test func flagAloneFallsBackToTheChosenScenesOwnLight() {
        let config = DesignHarnessConfiguration.parse(launchArguments: ["-design-harness"])

        #expect(config?.scene == .blownSky)
        #expect(config?.sceneEV == StandInScene.blownSky.nominalEV)
    }

    @Test func sceneIsChosenByLaunchArgument() {
        for scene in StandInScene.allCases {
            let config = DesignHarnessConfiguration.parse(
                launchArguments: ["-design-harness", "-harness-scene", scene.rawValue]
            )

            #expect(config?.scene == scene)
            // Each scene carries the light it depicts, so naming a scene alone
            // is enough to see the HUD under that light.
            #expect(config?.sceneEV == scene.nominalEV)
        }
    }

    @Test func sceneEVIsChosenByLaunchArgumentAndOverridesTheScenesOwn() {
        let config = DesignHarnessConfiguration.parse(
            launchArguments: [
                "-design-harness", "-harness-scene", "dim-interior", "-harness-ev", "9.5",
            ]
        )

        #expect(config?.scene == .dimInterior)
        #expect(config?.sceneEV == 9.5)
    }

    @Test func unparseableValuesFallBackRatherThanFailingToLaunch() {
        let config = DesignHarnessConfiguration.parse(
            launchArguments: [
                "-design-harness", "-harness-scene", "nonsense", "-harness-ev", "bright",
            ]
        )

        #expect(config?.scene == .blownSky)
        #expect(config?.sceneEV == StandInScene.blownSky.nominalEV)
    }

    @Test func valuelessTrailingOptionIsIgnored() {
        let config = DesignHarnessConfiguration.parse(
            launchArguments: ["-design-harness", "-harness-scene"]
        )

        #expect(config?.scene == .blownSky)
    }

    /// The three scenes the variant work is judged against: a blown-out sky, a
    /// dim interior, and a high-contrast mixed scene — each at a light level that
    /// is genuinely different, so the HUD is seen at the ends of its range.
    @Test func theThreeScenesSpanTheMetersRange() {
        #expect(StandInScene.allCases == [.blownSky, .dimInterior, .mixedContrast])
        #expect(StandInScene.blownSky.nominalEV > StandInScene.mixedContrast.nominalEV)
        #expect(StandInScene.mixedContrast.nominalEV > StandInScene.dimInterior.nominalEV)
    }
}
