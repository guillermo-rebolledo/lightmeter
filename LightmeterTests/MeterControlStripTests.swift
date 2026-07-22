import Testing
@testable import Lightmeter

/// The one piece of real logic in the inline control strip: which strip section
/// the guided tour force-opens for a given step, so the `.compensation`,
/// `.meteringPattern`, and priority controls the strip hides in ordinary use
/// still resolve their tour anchors when their step is active.
struct MeterControlStripTests {
    @Test func compensationStepOpensCompensation() {
        #expect(MeterControlStrip.tourSection(for: .compensation) == .compensation)
    }

    @Test func meteringPatternStepOpensPattern() {
        #expect(MeterControlStrip.tourSection(for: .meteringPattern) == .pattern)
    }

    @Test func priorityStepOpensPriority() {
        #expect(MeterControlStrip.tourSection(for: .priorityAndChips) == .priority)
    }

    @Test func persistentStepsForceNothingOpen() {
        #expect(MeterControlStrip.tourSection(for: .evReadout) == nil)
        #expect(MeterControlStrip.tourSection(for: .dial) == nil)
        #expect(MeterControlStrip.tourSection(for: .settings) == nil)
    }

    @Test func noTourLeavesSectionsCollapsed() {
        #expect(MeterControlStrip.tourSection(for: nil) == nil)
    }
}
