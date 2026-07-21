import CoreGraphics
import Foundation
import Observation

// MARK: - MeterViewModel (state layer between LightSource and the UI)
//
// Second test seam. Driven by an injected `LightSource` so its behavior is tested
// with a fake — no camera required. Owns, in later tickets:
//   - latest reading + derived exposure triangle (#3)      ← latest reading + EV here
//   - active priority mode and which chip the dial is bound to (#4, #5)
//   - metering pattern + spot location (#6)
//   - EV compensation (#8)
//   - freeze/hold state and surfaced advisories (#7)
//
// The concrete AVFoundation `LightSource` lives in Camera/ and is the thin,
// hand-validated edge that is deliberately not unit-tested.

/// Observable state for the meter screen: consumes exposure-metadata readings
/// from an injected `LightSource` and publishes the latest scene EV@ISO100.
@MainActor
@Observable
final class MeterViewModel {
    /// Where the meter is in its lifecycle, driving which UI is shown.
    enum Status: Equatable {
        /// Not yet started (or stopped).
        case idle
        /// Live metering: the preview is the hero and the EV readout updates.
        case metering
        /// Camera access was denied; the UI shows a graceful denied state.
        case denied
    }

    /// The current lifecycle status.
    private(set) var status: Status = .idle

    /// The most recent raw metadata sample, or `nil` before the first reading.
    private(set) var latestReading: LightReading?

    /// The most recent scene exposure value at ISO 100, or `nil` before the first
    /// reading.
    private(set) var ev: Double?

    /// Whether the current reading is held while incoming source emissions are
    /// ignored. A reading must exist before the meter can be frozen.
    private(set) var isFrozen = false

    /// Which leg the photographer holds fixed and which the engine solves.
    /// Aperture-priority (locks aperture, solves shutter) is the v1 default.
    private(set) var mode: PriorityMode = .aperturePriority

    /// The ISO the photographer has set (their film stock / sensor setting).
    /// Always an input; drives the solve in both priority modes.
    private(set) var iso: Double = 100

    /// The aperture the photographer has set. A fixed input in aperture-priority
    /// (the shutter is solved from it); ignored — solved instead — in
    /// shutter-priority.
    private(set) var aperture: Double = 8

    /// The shutter duration (seconds) the photographer has set. A fixed input in
    /// shutter-priority (the aperture is solved from it); ignored — solved
    /// instead — in aperture-priority.
    private(set) var shutter: Double = 1.0 / 125

    /// The exposure triangle for the current scene: the two legs the
    /// photographer set plus the solved leg, each snapped to a real, dial-able
    /// stop. The solved leg is `nil` until the scene has been metered.
    var triangle: ExposureTriangle {
        ExposureEngine.solvedTriangle(
            mode: mode,
            evAtISO100: ev,
            iso: iso,
            aperture: aperture,
            shutter: shutter
        )
    }

    /// Safety guidance derived from the current unsnapped solve.
    var advisories: [ExposureAdvisory] {
        ExposureEngine.advisories(
            mode: mode,
            evAtISO100: ev,
            iso: iso,
            aperture: aperture,
            shutter: shutter
        )
    }

    /// Which chip's leg the single arc dial is bound to, or `nil` when no dial is
    /// active. Only an editable (set, not solved) leg can be bound, and only one
    /// at a time — binding a new leg replaces the old.
    private(set) var boundComponent: ExposureComponent?

    /// How the frame is metered: center-weighted whole-frame average (the
    /// default) or a tap-placed spot.
    private(set) var pattern: MeteringPattern = .average

    /// The placed spot as a normalized device point in `[0, 1] × [0, 1]`, or
    /// `nil` before any spot has been placed. Only meaningful in `.spot`.
    private(set) var spot: CGPoint?

    private let source: LightSource
    private var meteringTask: Task<Void, Never>?

    init(source: LightSource) {
        self.source = source
    }

    /// Requests camera access and, if granted, begins metering. On denial the
    /// status flips to `.denied` and no readings are consumed.
    func start() async {
        guard status != .metering else { return }

        switch await source.requestAuthorization() {
        case .denied:
            status = .denied
        case .authorized:
            // The permission prompt is a suspension point. If the view went away
            // while we were waiting (its `.task` was cancelled and `stop()` ran),
            // don't spin the camera back up.
            guard !Task.isCancelled else { return }

            status = .metering
            let stream = source.start()
            // Apply the chosen metering pattern to the fresh session so the first
            // read already meters the right point.
            applyMeteringPattern()
            meteringTask = Task { [weak self] in
                for await reading in stream {
                    // Re-bind self each iteration so the loop doesn't retain the
                    // view-model across suspension points (avoids a retain cycle
                    // via the stored `meteringTask`).
                    guard let self else { break }
                    guard self.isFrozen == false else { continue }
                    guard let ev = ExposureEngine.evAtISO100(for: reading) else { continue }
                    self.latestReading = reading
                    self.ev = ev
                }
                // The stream can finish on its own — e.g. capture configuration
                // fails because no camera is available. Reset status so the UI
                // doesn't stay stuck on the metering screen and a later start()
                // isn't blocked by the guard above.
                if let self, self.status == .metering {
                    self.status = .idle
                }
            }
        }
    }

    /// Stops metering and returns to idle. Safe to call when not metering.
    func stop() {
        meteringTask?.cancel()
        meteringTask = nil
        source.stop()
        if status == .metering {
            status = .idle
        }
        isFrozen = false
    }

    /// Holds the latest valid reading, or resumes accepting live source updates.
    /// Before the first reading there is nothing to hold, so this is a no-op.
    func toggleFreeze() {
        guard latestReading != nil || isFrozen else { return }
        isFrozen.toggle()
    }

    /// Sets the photographer's ISO. The triangle re-solves its solved leg from
    /// the new value on the next read.
    func setISO(_ value: Double) {
        iso = value
    }

    /// Sets the photographer's aperture (the fixed leg in aperture-priority).
    /// The triangle re-solves from the new value on the next read.
    func setAperture(_ value: Double) {
        aperture = value
    }

    /// Sets the photographer's shutter (the fixed leg in shutter-priority). The
    /// triangle re-solves from the new value on the next read.
    func setShutter(_ value: Double) {
        shutter = value
    }

    // MARK: - Priority mode

    /// Switches the active priority mode. If the arc dial was bound to the leg
    /// that becomes solved (and so non-editable) under the new mode, it unbinds
    /// so the dial never drives a computed leg.
    func setMode(_ newMode: PriorityMode) {
        mode = newMode
        if boundComponent == newMode.solvedComponent {
            boundComponent = nil
        }
    }

    /// Toggles between aperture- and shutter-priority — the single mode control.
    func toggleMode() {
        setMode(mode.toggled)
    }

    // MARK: - Metering pattern

    /// Switches the metering pattern and routes the resulting region of interest
    /// to the source. Selecting the active pattern is a no-op. Choosing spot with
    /// no prior spot defaults it to the frame center so there is always a point to
    /// meter.
    func setPattern(_ newPattern: MeteringPattern) {
        guard pattern != newPattern else { return }
        pattern = newPattern
        if newPattern == .spot, spot == nil {
            spot = .frameCenter
        }
        applyMeteringPattern()
    }

    /// Toggles between average and spot — the single metering-pattern control.
    func togglePattern() {
        setPattern(pattern.toggled)
    }

    /// Places the spot at a normalized device point (from the preview layer's
    /// coordinate conversion), switching to spot metering and routing the point —
    /// clamped into the valid `[0, 1]` range — to the source's AE region of
    /// interest.
    func placeSpot(at point: CGPoint) {
        pattern = .spot
        spot = Self.clampedToFrame(point)
        applyMeteringPattern()
    }

    /// The region of interest the current pattern meters: `nil` (whole-frame
    /// average) for `.average`, or the placed spot (defaulting to center) for
    /// `.spot`.
    private var meteringPoint: CGPoint? {
        switch pattern {
        case .average: return nil
        case .spot: return spot ?? .frameCenter
        }
    }

    /// Routes the current pattern's region of interest to the source.
    private func applyMeteringPattern() {
        source.setExposurePointOfInterest(meteringPoint)
    }

    /// Clamps a normalized point into the `[0, 1] × [0, 1]` device range so a tap
    /// on a letterboxed edge can't push the region of interest off the frame.
    private static func clampedToFrame(_ point: CGPoint) -> CGPoint {
        CGPoint(
            x: min(max(point.x, 0), 1),
            y: min(max(point.y, 0), 1)
        )
    }

    // MARK: - Dial binding

    /// Whether `component` is an editable (set, not solved) leg the arc dial can
    /// drive. The solved leg is computed and non-editable, so it can't be bound.
    func isEditable(_ component: ExposureComponent) -> Bool {
        component != triangle.solved
    }

    /// Binds the arc dial to `component`'s chip, or unbinds if it is already the
    /// bound leg (tap to toggle). Non-editable (solved) legs are ignored. Only
    /// one leg is ever bound — binding a new one replaces the old.
    func bindDial(to component: ExposureComponent) {
        guard isEditable(component) else { return }
        boundComponent = (boundComponent == component) ? nil : component
    }

    /// The dial-able stops of the bound leg's scale, or empty when nothing is
    /// bound — what the arc dial lays out as its detents.
    var boundStops: [PhotographicScale.Stop] {
        boundComponent?.scale.stops ?? []
    }

    /// The index within `boundStops` of the bound leg's current value, or `nil`
    /// when nothing is bound — the stop the dial's fixed indicator points at.
    var boundStopIndex: Int? {
        guard let boundComponent else { return nil }
        let scale = boundComponent.scale
        return scale.stops.firstIndex(of: scale.snap(value(for: boundComponent)))
    }

    /// Drives the dial: sets the bound leg to the stop at `index` (clamped to the
    /// scale), re-solving the triangle live. No-op when nothing is bound.
    func setBoundStopIndex(_ index: Int) {
        guard let boundComponent else { return }
        let stops = boundComponent.scale.stops
        let value = stops[min(max(index, 0), stops.count - 1)].value
        switch boundComponent {
        case .iso: iso = value
        case .aperture: aperture = value
        case .shutter: shutter = value
        }
    }

    /// The current set value of a leg — its live stored input. The dial is only
    /// ever bound to an editable (set) leg, so this is always the value it drives.
    private func value(for component: ExposureComponent) -> Double {
        switch component {
        case .iso: return iso
        case .aperture: return aperture
        case .shutter: return shutter
        }
    }
}
