import Testing
@testable import Lightmeter

// The DEBUG-only instrumentation for the launch path (#112): the on-device repro
// tool for the "ruler dead for a beat after launch". The main-thread watchdog and
// the camera edge are hand-validated at runtime, but the pure pieces the instrument
// leans on — the launch-argument gate that keeps it off on an ordinary run, the
// stall boundary the watchdog decides on, and the greppable lines it logs — are
// pinned here.
//
// Everything under test is `#if DEBUG`; the test target always builds Debug, so no
// file-scope guard is needed (the reading-diagnostics tests rely on the same).
struct LaunchDiagnosticsTests {
    // MARK: - Launch-argument gate

    @Test func absentFlagLeavesDiagnosticsOff() {
        #expect(LaunchDiagnostics.isEnabled(launchArguments: []) == false)
        // A neighbouring instrument's flag must not switch this one on — the two
        // repros are independent gates.
        #expect(
            LaunchDiagnostics.isEnabled(
                launchArguments: ["/path/to/Lightmeter", "-reading-diagnostics"]
            ) == false
        )
    }

    @Test func flagTurnsDiagnosticsOn() {
        #expect(
            LaunchDiagnostics.isEnabled(
                launchArguments: ["/path/to/Lightmeter", "-launch-diagnostics"]
            )
        )
    }

    // MARK: - Stall boundary

    @Test func latencyBelowThresholdIsNotAStall() {
        // Ordinary scheduling jitter — the probe normally lands in well under a
        // millisecond — must not read as the main thread being blocked.
        #expect(LaunchDiagnostics.isStall(0) == false)
        #expect(LaunchDiagnostics.isStall(LaunchDiagnostics.hangThreshold - 0.001) == false)
    }

    @Test func latencyAtOrPastThresholdIsAStall() {
        // The boundary is inclusive: a round trip exactly at the threshold counts,
        // so the log never drops a stall sitting on the line.
        #expect(LaunchDiagnostics.isStall(LaunchDiagnostics.hangThreshold))
        // A 1.4s block — the kind that swallows a couple of seconds of drags — is
        // unambiguously a stall.
        #expect(LaunchDiagnostics.isStall(1.4))
    }

    // MARK: - Log lines

    @Test func milestoneLineCarriesTheEventAndItsOffset() {
        let line = LaunchDiagnostics.milestoneLine(event: "sessionRunning", sinceLaunchMS: 123.45)

        // Both halves of the finding must be legible: which step, and how long
        // after launch it happened.
        #expect(line.contains("event=sessionRunning"))
        #expect(line.contains("+123.5ms"))
    }

    @Test func stallLineCarriesTheDurationAndWhenItHappened() {
        let line = LaunchDiagnostics.stallLine(stallMS: 1400, sinceLaunchMS: 200)

        // A long stall early in launch is the swallowed-touch window — the duration
        // and its offset are the whole finding.
        #expect(line.contains("1400.0ms"))
        #expect(line.contains("at +200.0ms"))
    }
}
