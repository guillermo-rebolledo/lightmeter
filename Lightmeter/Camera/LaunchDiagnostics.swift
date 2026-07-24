#if DEBUG
import Foundation
import QuartzCore
import os

// MARK: - LaunchDiagnostics (DEBUG-only on-device repro instrument for #112)
//
// The Aperture/Shutter ruler was reported dead for a beat on launch — thumb it
// the instant the app opens and the first couple of seconds of drags are
// swallowed, then it starts tracking. The dial is *not* gated on the camera
// (`dialTarget` opens on the aperture leg, independent of any reading), so a
// waiting-for-first-reading stall is ruled out on inspection. The leading
// hypothesis is a main-thread hitch during camera warmup: a blocked main thread
// does not deliver touches, which presents exactly as "drags do nothing for a
// beat, then work." That cannot be judged from code — it needs an on-device
// repro. This is that repro, mirroring the `-reading-diagnostics` instrument
// (#111): with the `-launch-diagnostics` launch argument the launch path narrates
// itself to the unified log, answering the issue's questions without a debugger
// or Instruments attached:
//
//   1. Is the main thread blocked during the first ~1-2s, and for how long?  → a
//      lightweight watchdog probes the main queue from a background timer and
//      logs any stall past `hangThreshold`, with its duration and when in the
//      launch it happened — so "main was blocked for 1.4s at +200ms" reads
//      straight out of the log.
//   2. When does each warmup step actually happen relative to launch?  → the
//      camera marks the moment the session is asked to start, when it is running,
//      and when the first frame lands, each stamped with its offset from launch.
//   3. Is the ruler draggable within the first frames?  → the dial logs its first
//      received drag. Lined up against the stalls above, a first drag that only
//      lands *after* the stall window closes confirms the diagnosis; one that
//      lands early clears the main thread and points the fix elsewhere.
//
// The whole file is `#if DEBUG`, so a Release build carries none of it and the
// shipping launch path is byte-for-byte what it was. The gate is a launch
// argument on top of that, so even a Debug run is silent unless the repro is
// being run — the design harness' `-design-harness` contract.
enum LaunchDiagnostics {
    /// The launch argument that turns the instrument on. Absent → wholly inert.
    private static let enableFlag = "-launch-diagnostics"

    /// Whether this launch asked for launch diagnostics, resolved once so the gate
    /// cannot flip mid-session and log half a warmup.
    static let isEnabled = isEnabled(launchArguments: ProcessInfo.processInfo.arguments)

    /// The parse, split from the launch-time constant so the contract is testable
    /// without launching anything — `ReadingDiagnostics.isEnabled(launchArguments:)`'s
    /// pattern (a stored gate over a pure argument reader of the same name).
    static func isEnabled(launchArguments: [String]) -> Bool {
        launchArguments.contains(enableFlag)
    }

    /// The unified-log channel every diagnostic line goes to. Filter Console (or
    /// `log stream`) on `subsystem: com.lightmeter, category: launch` to watch a
    /// launch live, or copy the run into the issue as the captured finding.
    // Logged at `.notice`, not `.debug`: unlike the per-frame reading instrument,
    // this emits only a handful of sparse lines per launch that are meant to be
    // read and pasted into the issue. `.notice` persists them — so a run can be
    // pulled after the fact with `log show --predicate 'subsystem ==
    // "com.lightmeter"'` — and surfaces them in the Xcode console and Console.app
    // without opting into debug messages or streaming before launch.
    static let logger = Logger(subsystem: "com.lightmeter", category: "launch")

    /// A main-queue round trip slower than this counts as a stall worth logging —
    /// past it the main thread was busy enough to drop a frame. Tuned to ~one
    /// dropped frame (20ms): the 100ms then 33ms floors both came back clean on
    /// device, so the floor is dropped again to catch a train of single-frame
    /// hitches during camera startup that a coarser floor hides — while still well
    /// above the sub-millisecond a probe lands in when the main thread is idle.
    static let hangThreshold: CFTimeInterval = 0.02

    /// Whether a measured main-queue round-trip latency counts as a stall — the
    /// watchdog's decision, split out so the boundary is pinned by a test.
    static func isStall(_ latency: CFTimeInterval) -> Bool {
        latency >= hangThreshold
    }

    // MARK: - Milestones

    /// The warmup steps the instrument stamps, named once here so the call sites
    /// spread across the preview view, the camera, the sampler, and the dial cannot
    /// drift on a bare string. `firstDialDrag` is stamped by `noteFirstDialDrag`;
    /// the rest ride `mark`.
    ///
    /// The three the issue names as suspects — preview-layer attach, session start,
    /// first-frame delivery — are each here, so a stall the watchdog reports can be
    /// pinned to the step it overlaps rather than guessed at. `previewAttach`
    /// brackets the *main-thread* attach work, the one suspect that does not run on
    /// a background queue.
    enum Milestone: String {
        case previewAttachBegan
        case previewAttachEnded
        case authorizationResolved
        case sessionStartRequested
        case sessionRunning
        case firstFrame
        case firstDialDrag
    }

    // MARK: - Log lines (pure over their inputs — no clock, no device)

    /// Formats a warmup milestone into a compact, greppable line: the event and
    /// how long after launch it happened, so the ordering — and any gap — reads at
    /// a glance. Pure over its inputs, so the line's shape is a test's to pin.
    static func milestoneLine(event: String, sinceLaunchMS: Double) -> String {
        String(format: "event=%@ +%.1fms", event, sinceLaunchMS)
    }

    /// Formats one detected stall: how long the main thread was unresponsive and
    /// when in the launch it happened. The pair is the whole finding — a long
    /// stall early in launch is the swallowed-touch window the issue describes.
    static func stallLine(stallMS: Double, sinceLaunchMS: Double) -> String {
        String(format: "main-thread stall %.1fms at +%.1fms", stallMS, sinceLaunchMS)
    }

    // MARK: - The launch clock

    /// The zero point every offset is measured from: the first time anything
    /// touches the instrument, which `arm()` forces at the meter screen's first
    /// appearance — the moment the photographer can first reach for the dial.
    static let launchReference: CFTimeInterval = CACurrentMediaTime()

    /// Milliseconds elapsed since `launchReference`. Read on whatever thread marks
    /// a milestone — the camera queues, the main actor — so it takes no lock; the
    /// monotonic clock is safe to read from anywhere.
    static func elapsedMilliseconds() -> Double {
        (CACurrentMediaTime() - launchReference) * 1000
    }

    // MARK: - Markers

    /// Stamps a warmup milestone with its offset from launch. Safe to call from any
    /// thread — it only reads the clock and logs — so the preview view (main) and
    /// the camera queues (background) can mark their own steps without hopping the
    /// actor.
    static func mark(_ milestone: Milestone) {
        guard isEnabled else { return }
        logger.notice(
            "\(milestoneLine(event: milestone.rawValue, sinceLaunchMS: elapsedMilliseconds()), privacy: .public)"
        )
    }

    // MARK: - Main-thread watchdog (main-actor state)

    /// The running watchdog, or `nil` before `arm()` / after it stops. Touched only
    /// on the main actor, so it needs no lock of its own.
    @MainActor private static var monitor: MainThreadHangMonitor?

    /// Whether the first post-launch drag has already been logged, so the marker
    /// fires exactly once however many drags follow.
    @MainActor private static var didNoteFirstDialDrag = false

    /// Starts watching the main thread for stalls and pins the launch clock. Called
    /// from the meter screen's first appearance; idempotent, so a re-entrant task
    /// cannot start a second watchdog. Self-stops after a warmup window even if the
    /// dial is never touched, so the probe does not run for the session's life.
    @MainActor static func arm() {
        guard isEnabled, monitor == nil else { return }
        _ = launchReference // Resolve the zero point at the first-appearance call site.
        logger.notice("armed — watching the main thread for stalls ≥ \(Int(hangThreshold * 1000), privacy: .public)ms")

        let monitor = MainThreadHangMonitor(reference: launchReference) { stall, at in
            logger.notice(
                "\(stallLine(stallMS: stall * 1000, sinceLaunchMS: at * 1000), privacy: .public)"
            )
        }
        Self.monitor = monitor
        monitor.start()

        // Stop watching after the warmup window closes even if the dial is never
        // thumbed — the swallowed-touch window the issue describes is the first
        // couple of seconds, so a few seconds of watching covers it with margin.
        // The block runs on the main queue, so it is already on the main actor;
        // `assumeIsolated` states that to the compiler rather than hopping again.
        DispatchQueue.main.asyncAfter(deadline: .now() + warmupWindow) {
            MainActor.assumeIsolated { stopMonitor() }
        }
    }

    /// Logs the first drag the ruler receives after launch and stops the watchdog —
    /// the success signal the issue asks to confirm ("draggable within the first
    /// frames"). Lined up against the stall log, it says whether the dial came
    /// alive before or after the main thread was blocked.
    @MainActor static func noteFirstDialDrag() {
        guard isEnabled, !didNoteFirstDialDrag else { return }
        didNoteFirstDialDrag = true
        logger.notice(
            "\(milestoneLine(event: Milestone.firstDialDrag.rawValue, sinceLaunchMS: elapsedMilliseconds()), privacy: .public)"
        )
        stopMonitor()
    }

    /// How many updates the first drag has delivered, and whether it has ended — so
    /// a "moved a little then stuck" drag reads as either the updates drying up (the
    /// gesture was cancelled / touches stopped) or the updates continuing while the
    /// value clamps (a dial-math stall). Touched only on the main actor, where the
    /// gesture runs.
    @MainActor private static var firstDragChangeCount = 0
    @MainActor private static var didEndFirstDialDrag = false

    /// Logs each update of the *first* drag (capped, so a long smooth drag can't
    /// flood the log) with how far the finger has travelled. If dx keeps climbing
    /// while the dial visually sticks, the fault is the dial's drag→stop math, not
    /// touch delivery; if the updates simply stop, the gesture was interrupted.
    @MainActor static func noteDialDragChange(translationWidth: Double) {
        guard isEnabled, didNoteFirstDialDrag, !didEndFirstDialDrag else { return }
        firstDragChangeCount += 1
        guard firstDragChangeCount <= 12 else { return }
        logger.notice(
            "dialDragChange #\(firstDragChangeCount, privacy: .public) dx=\(String(format: "%.1f", translationWidth), privacy: .public) at +\(String(format: "%.1f", elapsedMilliseconds()), privacy: .public)ms"
        )
    }

    /// Logs when the first drag ends, with how many updates it delivered — the
    /// companion to `noteDialDragChange`. A low count here on a drag the finger
    /// never lifted from is the gesture being cancelled out from under it.
    @MainActor static func noteFirstDialDragEnded() {
        guard isEnabled, didNoteFirstDialDrag, !didEndFirstDialDrag else { return }
        didEndFirstDialDrag = true
        logger.notice(
            "dialDragEnded afterChanges=\(firstDragChangeCount, privacy: .public) at +\(String(format: "%.1f", elapsedMilliseconds()), privacy: .public)ms"
        )
    }

    /// How long the watchdog runs before giving up on its own — comfortably past
    /// the first-couple-of-seconds window the swallowed touches fall in.
    private static let warmupWindow: CFTimeInterval = 8

    @MainActor private static func stopMonitor() {
        monitor?.stop()
        monitor = nil
    }
}

// MARK: - MainThreadHangMonitor

/// A lightweight main-thread watchdog: a background timer bounces a probe off the
/// main queue and measures how long the round trip takes. A long latency means the
/// main thread was busy and could not run the probe — which is also when it could
/// not deliver a touch, so the latency is a direct read on the swallowed-drag
/// window. Only ever one probe is in flight, so a single stall logs one line
/// carrying its full duration rather than a burst as the backlog drains.
///
/// The AVFoundation edge stays hand-validated; this is the same kind of runtime
/// instrument, so its behaviour is confirmed on device, not unit-tested — only the
/// pure stall boundary it leans on (`LaunchDiagnostics.isStall`) is pinned.
private final class MainThreadHangMonitor {
    private let queue = DispatchQueue(label: "com.lightmeter.launch.hang", qos: .utility)
    private let reference: CFTimeInterval
    private let probeInterval: CFTimeInterval
    private let threshold: CFTimeInterval
    private let onStall: (_ stall: CFTimeInterval, _ at: CFTimeInterval) -> Void

    /// A timer source, retained so it keeps firing. Touched only on `queue`.
    private var timer: DispatchSourceTimer?
    /// Whether the last probe is still waiting on the main thread. Touched only on
    /// `queue`, so it needs no lock — and it is what keeps a single stall to a
    /// single log line: while a probe is outstanding no new one is sent.
    private var probePending = false

    init(
        reference: CFTimeInterval,
        probeInterval: CFTimeInterval = 0.02,
        threshold: CFTimeInterval = LaunchDiagnostics.hangThreshold,
        onStall: @escaping (_ stall: CFTimeInterval, _ at: CFTimeInterval) -> Void
    ) {
        self.reference = reference
        self.probeInterval = probeInterval
        self.threshold = threshold
        self.onStall = onStall
    }

    func start() {
        queue.async { [weak self] in
            guard let self else { return }
            let timer = DispatchSource.makeTimerSource(queue: self.queue)
            timer.schedule(deadline: .now() + self.probeInterval, repeating: self.probeInterval)
            timer.setEventHandler { [weak self] in self?.probe() }
            self.timer = timer
            timer.resume()
        }
    }

    func stop() {
        queue.async { [weak self] in
            self?.timer?.cancel()
            self?.timer = nil
        }
    }

    /// Bounces one probe off the main queue, unless the previous one is still
    /// outstanding (the main thread is already blocked — piling on would only
    /// multiply the log lines for one stall).
    private func probe() {
        guard !probePending else { return }
        probePending = true
        let dispatched = CACurrentMediaTime()
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            let latency = CACurrentMediaTime() - dispatched
            self.queue.async { self.probePending = false }
            if LaunchDiagnostics.isStall(latency) {
                self.onStall(latency, dispatched - self.reference)
            }
        }
    }
}
#endif
