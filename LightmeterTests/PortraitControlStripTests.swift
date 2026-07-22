import Testing
@testable import Lightmeter

/// The one piece of real logic in the inline control strip: which strip section
/// the guided tour force-opens for a given step, so the `.compensation`,
/// `.meteringPattern`, and priority controls the strip hides in ordinary use
/// still resolve their tour anchors when their step is active.
struct PortraitControlStripTests {
    @Test func compensationStepOpensCompensation() {
        #expect(PortraitControlStrip.tourSection(for: .compensation) == .compensation)
    }

    @Test func meteringPatternStepOpensPattern() {
        #expect(PortraitControlStrip.tourSection(for: .meteringPattern) == .pattern)
    }

    @Test func priorityStepOpensPriority() {
        #expect(PortraitControlStrip.tourSection(for: .priorityAndChips) == .priority)
    }

    @Test func persistentStepsForceNothingOpen() {
        #expect(PortraitControlStrip.tourSection(for: .evReadout) == nil)
        #expect(PortraitControlStrip.tourSection(for: .dial) == nil)
        #expect(PortraitControlStrip.tourSection(for: .settings) == nil)
    }

    @Test func noTourLeavesSectionsCollapsed() {
        #expect(PortraitControlStrip.tourSection(for: nil) == nil)
    }
}
