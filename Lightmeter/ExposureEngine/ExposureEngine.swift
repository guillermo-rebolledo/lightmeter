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
    static func evAtISO100(iso: Double, exposureDuration: Double, aperture: Double) -> Double {
        let apertureTerm = log2((aperture * aperture) / exposureDuration)
        let isoTerm = log2(iso / 100)
        return apertureTerm - isoTerm
    }

    /// Convenience overload converting a raw `LightReading` sample straight to EV@ISO100.
    static func evAtISO100(for reading: LightReading) -> Double {
        evAtISO100(
            iso: reading.iso,
            exposureDuration: reading.exposureDuration,
            aperture: reading.aperture
        )
    }
}
