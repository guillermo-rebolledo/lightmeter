import Foundation
import Observation

/// User-adjustable meter behavior backed by local preferences.
@MainActor
@Observable
final class MeterPreferences {
    var increment: StopIncrement {
        didSet {
            defaults?.set(increment.rawValue, forKey: Keys.increment)
        }
    }

    var calibrationOffset: Double {
        didSet {
            defaults?.set(calibrationOffset, forKey: Keys.calibrationOffset)
        }
    }

    private let defaults: UserDefaults?

    init(defaults: UserDefaults? = .standard) {
        self.defaults = defaults
        increment = StopIncrement(
            rawValue: defaults?.string(forKey: Keys.increment) ?? ""
        ) ?? .third
        calibrationOffset = defaults?.double(forKey: Keys.calibrationOffset) ?? 0
    }

    private enum Keys {
        static let increment = "meter.stopIncrement"
        static let calibrationOffset = "meter.calibrationOffset"
    }
}
