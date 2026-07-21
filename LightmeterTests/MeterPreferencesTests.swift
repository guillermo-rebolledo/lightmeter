import Foundation
import Testing
@testable import Lightmeter

@MainActor
struct MeterPreferencesTests {
    @Test func preferencesRestorePersistedValues() throws {
        let suiteName = "MeterPreferencesTests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let preferences = MeterPreferences(defaults: defaults)
        preferences.increment = .full
        preferences.calibrationOffset = 1.0 / 3
        preferences.hasSeenGuidedTour = true

        let restored = MeterPreferences(defaults: defaults)

        #expect(restored.increment == .full)
        #expect(abs(restored.calibrationOffset - (1.0 / 3)) < 1e-12)
        #expect(restored.hasSeenGuidedTour)
    }
}
