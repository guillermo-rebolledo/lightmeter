import Testing
@testable import Lightmeter

/// The mode row's real logic: which segments each pair offers, and what every
/// segment says it is — including to VoiceOver, which can't see the small-caps
/// glyph or the accent tint. Pure over the domain enums the row is built from, so
/// it's tested without a view, the same shape as `MeterStatusPills.Control` and
/// `ExposureChipsView.role(...)`.
///
/// The *behaviour* behind a tap — switching mode (and re-pointing the dial),
/// switching pattern — is `MeterViewModel`'s and is covered by its own tests; the
/// row only relocates and labels the controls.
struct MeterModeRowTests {
    // MARK: - The two pairs

    /// The priority pair is the two modes, in mode-dial order (aperture, shutter).
    @Test func thePriorityPairIsTheTwoModes() {
        #expect(PriorityMode.allCases == [.aperturePriority, .shutterPriority])
    }

    /// The pattern pair is average and spot — and *only* those. The handoff drew an
    /// incident segment; the app has no such pattern, so the type itself is what
    /// guarantees no incident segment can be shown.
    @Test func thePatternPairIsAverageAndSpotWithNoIncident() {
        #expect(MeteringPattern.allCases == [.average, .spot])
    }

    // MARK: - VoiceOver

    /// Each segment names its axis, so a mode segment and a pattern segment are
    /// distinguishable when read aloud rather than both sounding like the same kind
    /// of choice — the small-caps glyph alone doesn't carry that.
    @Test func eachSegmentNamesItsAxis() {
        #expect(PriorityMode.aperturePriority.accessibilityLabel == "Aperture priority")
        #expect(PriorityMode.shutterPriority.accessibilityLabel == "Shutter priority")
        #expect(MeteringPattern.average.accessibilityLabel == "Average metering")
        #expect(MeteringPattern.spot.accessibilityLabel == "Spot metering")

        // The two axes never collide: no priority segment reads like a pattern one.
        let priority = Set(PriorityMode.allCases.map(\.accessibilityLabel))
        let pattern = Set(MeteringPattern.allCases.map(\.accessibilityLabel))
        #expect(priority.isDisjoint(with: pattern))
    }

    /// No segment leaves a VoiceOver label — or its on-screen small-caps glyph —
    /// empty; both pairs are always fully labelled.
    @Test func noSegmentLeavesALabelEmpty() {
        for mode in PriorityMode.allCases {
            #expect(mode.accessibilityLabel.isEmpty == false)
            #expect(mode.label.isEmpty == false)
        }
        for pattern in MeteringPattern.allCases {
            #expect(pattern.accessibilityLabel.isEmpty == false)
            #expect(pattern.label.isEmpty == false)
        }
    }
}
