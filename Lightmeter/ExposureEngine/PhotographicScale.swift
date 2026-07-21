import Foundation

// MARK: - PhotographicScale (standard dial-able stops)
//
// A standard photographic scale — ISO, aperture, or shutter — as an ordered set
// of the real, marked stops a camera actually offers. Snapping an arbitrary
// computed value to its nearest stop is what makes a solved exposure dial-able:
// the app never tells you "1/137 s", it tells you "1/125", a click you can set.
//
// Stops are spaced one increment apart (1/3 stop in v1). The marked value is the
// nominal one printed on the dial (f/11, not 11.31; 1/125 s, not 1/128), so
// snapping is done in stop-space (log2) where the spacing is uniform, not in
// linear value-space where it is not.

/// A standard photographic scale of dial-able stops, able to snap an arbitrary
/// value to the nearest real stop.
struct PhotographicScale: Sendable {
    /// A single marked stop: the precise value used for math and the label a
    /// photographer reads off a camera dial.
    struct Stop: Equatable, Sendable {
        /// The precise value in the scale's natural unit — ISO sensitivity,
        /// f-number, or shutter duration in seconds.
        let value: Double
        /// The dial marking, e.g. `"400"`, `"5.6"`, `"1/125"`, `"2\""`.
        let label: String
    }

    /// The stops, ascending by `value`. Never empty.
    let stops: [Stop]

    /// Snaps `value` to the nearest stop measured in stop-space (log2), so a
    /// value halfway (in stops) between two marks rounds to the closer mark.
    /// Out-of-range inputs clamp to the nearest endpoint. Non-positive or
    /// non-finite inputs fall back to the lowest stop rather than producing a
    /// meaningless result. On an exact tie the lower stop wins.
    func snap(_ value: Double) -> Stop {
        guard value > 0, value.isFinite else { return stops[0] }
        let target = log2(value)
        return stops.min { lhs, rhs in
            abs(log2(lhs.value) - target) < abs(log2(rhs.value) - target)
        }!
    }
}

// MARK: - Standard 1/3-stop scales

extension PhotographicScale {
    /// Standard 1/3-stop ISO sensitivities, ISO 25–25600.
    static let iso = PhotographicScale(
        stops: [
            25, 32, 40, 50, 64, 80,
            100, 125, 160, 200, 250, 320,
            400, 500, 640, 800, 1000, 1250,
            1600, 2000, 2500, 3200, 4000, 5000,
            6400, 8000, 10000, 12800, 16000, 20000, 25600,
        ].map { Stop(value: $0, label: String(Int($0))) }
    )

    /// Standard 1/3-stop f-numbers, f/1.0–f/32.
    static let aperture = PhotographicScale(
        stops: [
            1.0, 1.1, 1.2, 1.4, 1.6, 1.8,
            2.0, 2.2, 2.5, 2.8, 3.2, 3.5,
            4.0, 4.5, 5.0, 5.6, 6.3, 7.1,
            8.0, 9.0, 10, 11, 13, 14,
            16, 18, 20, 22, 25, 29, 32,
        ].map { Stop(value: $0, label: trimmedNumber($0)) }
    )

    /// Standard 1/3-stop shutter durations (seconds), 1/8000 s–30 s. Marked the
    /// way cameras mark them: `1/N` for sub-second speeds, `N"` for whole
    /// seconds and above.
    static let shutter = PhotographicScale(
        stops: fractional([
            8000, 6400, 5000, 4000, 3200, 2500,
            2000, 1600, 1250, 1000, 800, 640,
            500, 400, 320, 250, 200, 160,
            125, 100, 80, 60, 50, 40,
            30, 25, 20, 15, 13, 10, 8, 6, 5, 4,
        ])
            + [
                Stop(value: 0.3, label: "0.3\""),
                Stop(value: 0.4, label: "0.4\""),
                Stop(value: 0.5, label: "0.5\""),
                Stop(value: 0.6, label: "0.6\""),
                Stop(value: 0.8, label: "0.8\""),
            ]
            + seconds([1, 1.3, 1.6, 2, 2.5, 3, 4, 5, 6, 8, 10, 13, 15, 20, 25, 30])
    )

    /// Sub-second shutter stops from their reciprocal denominators, `1/N`.
    private static func fractional(_ denominators: [Double]) -> [Stop] {
        denominators
            .map { Stop(value: 1.0 / $0, label: "1/\(Int($0))") }
            .sorted { $0.value < $1.value }
    }

    /// Whole-second-and-above shutter stops, marked `N"`.
    private static func seconds(_ values: [Double]) -> [Stop] {
        values.map { Stop(value: $0, label: "\(trimmedNumber($0))\"") }
    }

    /// Renders a scale value without a trailing `.0` (`8`, not `8.0`; `5.6`
    /// stays `5.6`).
    private static func trimmedNumber(_ value: Double) -> String {
        value == value.rounded() ? String(Int(value)) : String(value)
    }
}
