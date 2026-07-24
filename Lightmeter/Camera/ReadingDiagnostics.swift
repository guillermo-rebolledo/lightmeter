#if DEBUG
import Foundation
import os

// MARK: - ReadingDiagnostics (DEBUG-only on-device repro instrument for #111)
//
// The "EV @ ISO 100" headline was reported frozen on a real device — panning
// from a bright window to a dark corner left the screen's largest number
// unchanged. The pipeline reads correct on inspection (see #111), so the bug
// cannot be judged from code; it needs an on-device repro. This is the tool for
// that repro: with the `-reading-diagnostics` launch argument, the reading path
// narrates itself to the unified log, answering the three questions the issue
// poses without a debugger attached:
//
//   1. Is `ReadingSampler.captureOutput` firing, and are `device.iso` /
//      `device.exposureDuration` varying with the scene, or pinned?  → each
//      emitted reading is a line, and `ReadingSpans` reports the range each leg
//      *and* the resulting EV travelled, so "all three pinned" (a stuck AE)
//      reads differently from "legs move but EV doesn't" (a computation fault).
//   2. Is the device left in a locked exposure state after configuration?  →
//      `exposureMode` rides every line; anything but `2`
//      (`.continuousAutoExposure`) is the fault.
//   3. Is `rawEV` reaching the observable on the main actor?  → the view-model
//      logs each update from the main-actor loop that sets it.
//
// The whole file is `#if DEBUG`, so a Release build carries none of it and the
// shipping camera path is byte-for-byte what it was. The gate is a launch
// argument on top of that, so even a Debug run is silent unless the repro is
// being run — mirroring the design harness' `-design-harness` contract.

enum ReadingDiagnostics {
    /// The launch argument that turns the instrument on. Absent → wholly inert.
    private static let enableFlag = "-reading-diagnostics"

    /// Whether this launch asked for reading diagnostics, resolved once at first
    /// touch so the gate cannot flip mid-session and log half a pan.
    static let isEnabled = isEnabled(launchArguments: ProcessInfo.processInfo.arguments)

    /// The parse, split from the launch-time constant so the contract is testable
    /// without launching anything — the design harness' `forcesGlassFallback`
    /// pattern (a stored gate over a pure argument reader of the same name).
    static func isEnabled(launchArguments: [String]) -> Bool {
        launchArguments.contains(enableFlag)
    }

    /// The unified-log channel every diagnostic line goes to. Filter Console (or
    /// `log stream`) on `subsystem: com.lightmeter, category: reading` to watch a
    /// pan live, or copy the run into the issue as the captured finding.
    static let logger = Logger(subsystem: "com.lightmeter", category: "reading")

    /// Formats one emitted reading into a compact, greppable log line: the three
    /// legs the camera chose, the EV they resolve to (quoted at ISO 100, per
    /// ADR-0001), the exposure mode the device is in, and the running range each
    /// leg and the EV have covered — so a freeze, and *which* value is frozen, is
    /// visible at a glance rather than by eyeballing a column of numbers.
    ///
    /// Pure over its inputs — no device access — so the line's shape is pinned by a
    /// test rather than read off a screenshot.
    static func line(
        reading: LightReading,
        ev: Double,
        exposureModeRawValue: Int,
        spans: ReadingSpans
    ) -> String {
        String(
            format: "evISO100=%.2f iso=%g dur=%.5fs f/%g mode=%d "
                + "| range ev=%@ iso=%@ dur=%@ n=%d",
            ev,
            reading.iso,
            reading.exposureDuration,
            reading.aperture,
            exposureModeRawValue,
            Self.rangeText(spans.ev.span, format: "%.2f"),
            Self.rangeText(spans.iso.span, format: "%g"),
            Self.rangeText(spans.duration.span, format: "%.5f"),
            spans.count
        )
    }

    /// A span rendered for the log, or the app's em-dash while there is nothing to
    /// span yet.
    private static func rangeText(_ span: Double?, format: String) -> String {
        span.map { String(format: format, $0) } ?? "—"
    }
}

// MARK: - Span

/// Accumulates one stream of samples and reports how far they travelled — the
/// single number that answers "is this value genuinely frozen, or changing
/// subtly?". A span of ~0 across a long run while the phone pans a wide
/// brightness range is the freeze; a non-zero span is a value that only *looks*
/// static because the eye missed the movement.
///
/// A plain value type with no device or log dependency, so the accumulation is
/// unit-tested directly.
struct Span: Equatable {
    /// How many samples have been folded in.
    private(set) var count = 0

    /// The smallest sample seen, or `nil` before the first one.
    private(set) var min: Double?

    /// The largest sample seen, or `nil` before the first one.
    private(set) var max: Double?

    /// The distance between the smallest and largest samples, or `nil` before the
    /// first one. Zero across many samples is the frozen case.
    var span: Double? {
        guard let min, let max else { return nil }
        return max - min
    }

    /// Folds one sample into the running range.
    mutating func record(_ value: Double) {
        count += 1
        min = Swift.min(min ?? value, value)
        max = Swift.max(max ?? value, value)
    }
}

// MARK: - ReadingSpans

/// The running range of every leg the camera reports plus the EV they resolve
/// to, folded together as the phone pans. Bundled into one type — rather than
/// three spans threaded side by side — because they always travel together and
/// are always recorded from the same reading. Distinguishing a stuck AE (every
/// leg pinned) from an EV that ignores moving legs (a computation fault) is the
/// diagnostic fork #111 asks for, and it is exactly the comparison this makes
/// legible.
struct ReadingSpans: Equatable {
    private(set) var ev = Span()
    private(set) var iso = Span()
    private(set) var duration = Span()

    /// How many readings have been folded in — the same across every leg, since
    /// each reading records all three at once.
    var count: Int { ev.count }

    /// Folds one reading and its resolved EV@ISO100 into every running range.
    mutating func record(reading: LightReading, ev evValue: Double) {
        ev.record(evValue)
        iso.record(reading.iso)
        duration.record(reading.exposureDuration)
    }
}
#endif
