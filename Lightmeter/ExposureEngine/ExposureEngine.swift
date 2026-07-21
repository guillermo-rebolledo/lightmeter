import Foundation

// MARK: - ExposureEngine (pure, hardware-free)
//
// Primary test seam. Owns, in later tickets:
//   - camera AE metadata -> scene EV@ISO100 conversion (#3)      ← implemented here
//   - exposure-triangle solving for both priority modes (#3, #5)
//   - EV compensation + calibration offset (#8, #9)
//   - snapping to standard photographic scales at 1/3 / 1/2 / full stops (#3, #9)
//   - advisories: handholding / tripod / out-of-range (#7)
//
// No AVFoundation, no SwiftUI — everything here is deterministic and unit-tested.

enum ExposureEngine {
    /// Converts a camera's chosen auto-exposure triangle into the scene's exposure
    /// value, normalized to ISO 100.
    ///
    /// `EV = log2(N²/t) − log2(ISO/100)`, where `N` is the f-number, `t` is the
    /// exposure duration in seconds, and `ISO` is the sensitivity the camera used.
    /// Normalizing to ISO 100 makes the reading a property of the scene's light
    /// alone, independent of how sensitive the camera's sensor happened to be.
    ///
    /// - Parameters:
    ///   - iso: The ISO the camera's auto-exposure selected (e.g. 100, 400).
    ///   - exposureDuration: The exposure duration in seconds (e.g. `1.0/128`).
    ///   - aperture: The lens f-number `N` (e.g. 1.8, 16).
    /// - Returns: The scene exposure value at ISO 100.
    /// - Precondition: `iso`, `exposureDuration`, and `aperture` must all be
    ///   positive and finite. The `log2` terms produce NaN/±infinity otherwise;
    ///   use `evAtISO100(for:)` at the camera boundary to reject such readings.
    static func evAtISO100(iso: Double, exposureDuration: Double, aperture: Double) -> Double {
        let apertureTerm = log2((aperture * aperture) / exposureDuration)
        let isoTerm = log2(iso / 100)
        return apertureTerm - isoTerm
    }

    /// Converts a raw `LightReading` sample to EV@ISO100, rejecting physically
    /// impossible readings (non-positive or non-finite ISO, duration, or
    /// aperture) so NaN/±infinity can never reach the meter's EV state.
    ///
    /// - Returns: The scene EV@ISO100, or `nil` if the reading is invalid.
    static func evAtISO100(for reading: LightReading) -> Double? {
        guard
            reading.iso > 0, reading.iso.isFinite,
            reading.exposureDuration > 0, reading.exposureDuration.isFinite,
            reading.aperture > 0, reading.aperture.isFinite
        else {
            return nil
        }
        return evAtISO100(
            iso: reading.iso,
            exposureDuration: reading.exposureDuration,
            aperture: reading.aperture
        )
    }

    /// The raw shutter duration (seconds) that balances the exposure in
    /// aperture-priority: the photographer sets the ISO and aperture, and this
    /// solves the third leg from the scene's EV@ISO100.
    ///
    /// From `EV = log2(N²/t) − log2(ISO/100)`, solving for `t` at the scene's
    /// EV normalized to ISO 100:
    ///
    ///     t = N² / (2^EV100 · ISO/100)
    ///
    /// The result is exact — not yet snapped to a dial mark; feed it through
    /// `PhotographicScale.shutter` (or use `solvedTriangle`) to make it settable.
    ///
    /// - Precondition: `iso` and `aperture` must be positive and finite (the
    ///   scene's own EV is already validated at the camera boundary).
    static func shutterDuration(evAtISO100: Double, iso: Double, aperture: Double) -> Double {
        (aperture * aperture) / (pow(2, evAtISO100) * (iso / 100))
    }

    /// Builds the aperture-priority triangle: snaps the photographer's ISO and
    /// aperture to real stops and, once the scene has been metered, solves the
    /// shutter and snaps it too — flagging the shutter as the computed leg. This
    /// is the single place the aperture-priority mode (which leg is solved, and
    /// how) is expressed, so the pending and metered cases can't drift apart.
    ///
    /// - Parameters:
    ///   - evAtISO100: The scene's exposure value at ISO 100, or `nil` before the
    ///     first reading (the shutter is left `nil`/pending).
    ///   - iso: The ISO the photographer set (snapped to the ISO scale).
    ///   - aperture: The aperture the photographer set (snapped to the f-scale).
    static func solvedTriangle(evAtISO100: Double?, iso: Double, aperture: Double) -> ExposureTriangle {
        let isoStop = PhotographicScale.iso.snap(iso)
        let apertureStop = PhotographicScale.aperture.snap(aperture)
        let shutter = evAtISO100.map { ev in
            PhotographicScale.shutter.snap(
                shutterDuration(evAtISO100: ev, iso: isoStop.value, aperture: apertureStop.value)
            )
        }
        return ExposureTriangle(
            iso: isoStop,
            aperture: apertureStop,
            shutter: shutter,
            solved: .shutter
        )
    }
}
