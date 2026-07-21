import Testing
@testable import Lightmeter

/// Proves the test harness is wired to the app module and runs green.
/// Real domain tests (ExposureEngine, MeterViewModel) arrive in ticket #3.
struct SmokeTests {
    @Test func appModuleIsReachable() {
        #expect(AppInfo.name == "Lightmeter")
        #expect(!AppInfo.tagline.isEmpty)
    }
}
