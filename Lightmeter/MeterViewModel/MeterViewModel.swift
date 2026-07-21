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
            status = .metering
            let stream = source.start()
            meteringTask = Task { [weak self] in
                for await reading in stream {
                    // Re-bind self each iteration so the loop doesn't retain the
                    // view-model across suspension points (avoids a retain cycle
                    // via the stored `meteringTask`).
                    guard let self else { break }
                    self.latestReading = reading
                    self.ev = ExposureEngine.evAtISO100(for: reading)
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
    }
}
