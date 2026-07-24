import Testing
@testable import Lightmeter

// The DEBUG-only instrumentation for the live reading path (#111): the on-device
// repro tool for the "frozen EV headline". The camera edge itself is deliberately
// not unit-tested, but the pure pieces the instrument leans on — the span
// accumulator that says "frozen vs. moving", the per-leg range it folds, and the
// greppable line it logs — are pinned here, and so is the launch-argument gate
// that keeps the whole thing off on an ordinary run.
//
// Everything under test is `#if DEBUG`; the test target always builds Debug, so
// no file-scope guard is needed (the design-harness tests rely on the same).
struct ReadingDiagnosticsTests {
    // MARK: - Span

    @Test func emptySpanReportsNothing() {
        let span = Span()

        #expect(span.count == 0)
        #expect(span.min == nil)
        #expect(span.max == nil)
        #expect(span.span == nil)
    }

    @Test func oneSampleHasZeroSpan() {
        var span = Span()
        span.record(12.3)

        #expect(span.count == 1)
        #expect(span.min == 12.3)
        #expect(span.max == 12.3)
        #expect(span.span == 0)
    }

    @Test func spanIsTheDistanceBetweenTheSmallestAndLargestSamples() {
        var span = Span()
        // A pan from a dark corner up to a bright window, arriving out of order.
        for value in [8.0, 5.5, 14.25, 9.0, 5.5] {
            span.record(value)
        }

        #expect(span.count == 5)
        #expect(span.min == 5.5)
        #expect(span.max == 14.25)
        #expect(span.span == 8.75)
    }

    @Test func aFrozenValueLeavesTheSpanAtZeroHoweverManySamples() {
        var span = Span()
        for _ in 0..<200 {
            span.record(12.0)
        }

        // The whole point of the tool: many samples, no movement — the freeze.
        #expect(span.count == 200)
        #expect(span.span == 0)
    }

    // MARK: - ReadingSpans

    @Test func readingSpansFoldEveryLegAndTheEVFromOneReading() {
        var spans = ReadingSpans()
        spans.record(
            reading: LightReading(iso: 100, exposureDuration: 1.0 / 125, aperture: 8),
            ev: 12.0
        )
        spans.record(
            reading: LightReading(iso: 400, exposureDuration: 1.0 / 30, aperture: 8),
            ev: 8.0
        )

        #expect(spans.count == 2)
        #expect(spans.ev.span == 4)
        #expect(spans.iso.span == 300)
        #expect(spans.duration.min == 1.0 / 125)
        #expect(spans.duration.max == 1.0 / 30)
    }

    @Test func readingSpansSeparateAStuckAEFromAFrozenEV() {
        // Legs that move while the EV they resolve to does not — the computation
        // fault the issue asks the tool to tell apart from a pinned AE.
        var movingLegs = ReadingSpans()
        movingLegs.record(
            reading: LightReading(iso: 100, exposureDuration: 1.0 / 60, aperture: 8),
            ev: 12.0
        )
        movingLegs.record(
            reading: LightReading(iso: 200, exposureDuration: 1.0 / 60, aperture: 8),
            ev: 12.0
        )
        #expect(movingLegs.ev.span == 0)
        #expect((movingLegs.iso.span ?? 0) > 0)

        // Every leg pinned — a stuck AE — reads as zero everywhere.
        var stuck = ReadingSpans()
        for _ in 0..<50 {
            stuck.record(
                reading: LightReading(iso: 100, exposureDuration: 1.0 / 60, aperture: 8),
                ev: 12.0
            )
        }
        #expect(stuck.ev.span == 0)
        #expect(stuck.iso.span == 0)
        #expect(stuck.duration.span == 0)
    }

    // MARK: - Log line

    @Test func lineReportsEveryLegItReads() {
        var spans = ReadingSpans()
        spans.record(
            reading: LightReading(iso: 400, exposureDuration: 1.0 / 125, aperture: 1.8),
            ev: 9.5
        )

        let line = ReadingDiagnostics.line(
            reading: LightReading(iso: 400, exposureDuration: 1.0 / 125, aperture: 1.8),
            ev: 9.5,
            exposureModeRawValue: 2,
            spans: spans
        )

        // The values the issue asks to watch must each be legible in the line.
        #expect(line.contains("iso=400"))
        #expect(line.contains("f/1.8"))
        // EV is quoted at ISO 100 in the label itself (ADR-0001), not bare.
        #expect(line.contains("evISO100=9.5"))
        // Exposure mode 2 is `.continuousAutoExposure` — anything else is the bug.
        #expect(line.contains("mode=2"))
        #expect(line.contains("n=1"))
    }

    @Test func lineShowsTheRunningRangesSoAFreezeIsVisibleAtAGlance() {
        var spans = ReadingSpans()
        let reading = LightReading(iso: 100, exposureDuration: 1.0 / 60, aperture: 8)
        spans.record(reading: reading, ev: 12.0)
        spans.record(reading: reading, ev: 12.0)

        let line = ReadingDiagnostics.line(
            reading: reading,
            ev: 12.0,
            exposureModeRawValue: 2,
            spans: spans
        )

        // A frozen pan: every range reads zero, and the sample count still climbs.
        #expect(line.contains("ev=0"))
        #expect(line.contains("iso=0"))
        #expect(line.contains("n=2"))
    }

    // MARK: - Launch-argument gate

    @Test func absentFlagLeavesDiagnosticsOff() {
        #expect(ReadingDiagnostics.isEnabled(launchArguments: []) == false)
        #expect(
            ReadingDiagnostics.isEnabled(
                launchArguments: ["/path/to/Lightmeter", "-design-harness"]
            ) == false
        )
    }

    @Test func flagTurnsDiagnosticsOn() {
        #expect(
            ReadingDiagnostics.isEnabled(
                launchArguments: ["/path/to/Lightmeter", "-reading-diagnostics"]
            )
        )
    }
}
