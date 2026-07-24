import Testing
@testable import Lightmeter

/// The rule that decides which marks on the ruler carry a number.
///
/// It is worth its own suite because the obvious implementation — number every
/// third index — is right for exactly today's scales and wrong for any scale that
/// ever gains or loses a value. The rule the dial actually wants is *membership in
/// the full-stop scale*, and the thing that makes that rule usable is an alignment
/// between the increments that nothing in `PhotographicScale` enforces. So the
/// alignment is asserted here, first, and the graduations are checked against it.
struct DialGraduationsTests {
    private static let components: [ExposureComponent] = [.iso, .aperture, .shutter]

    // MARK: - The assumption underneath the rule

    /// Every full stop appears on the half- and third-stop scales too.
    ///
    /// This is what makes "major = a full stop" a *complete* rule rather than a
    /// filter: a full stop missing from the finer scale would be a numbered mark
    /// the photographer can never dial to, and the ruler would number 10 of 11
    /// full stops with nothing to say which one went missing. The scales are three
    /// hand-written lists, so nothing but this test holds them in step.
    @Test(arguments: components)
    func everyFullStopAppearsOnTheFinerScalesToo(_ component: ExposureComponent) {
        let fullStops = component.scale(for: .full).stops

        for increment in StopIncrement.allCases {
            let graduations = DialGraduations(component: component, increment: increment)
            let numbered = component.scale(for: increment).stops.indices
                .filter { graduations.isMajor($0) }

            #expect(
                numbered.count == fullStops.count,
                "\(component) at \(increment.label): \(numbered.count) of \(fullStops.count) full stops"
            )
        }
    }

    /// …and they appear in the same order, at the same values. Counting them is
    /// not enough on its own: a scale that dropped f/11 and gained a second f/8
    /// would count correctly and number the wrong marks.
    @Test(arguments: components)
    func theNumberedStopsAreTheFullStopsInOrder(_ component: ExposureComponent) {
        let fullStops = component.scale(for: .full).stops.map(\.value)

        for increment in StopIncrement.allCases {
            let stops = component.scale(for: increment).stops
            let graduations = DialGraduations(component: component, increment: increment)
            let numbered = stops.indices.filter { graduations.isMajor($0) }.map { stops[$0].value }

            #expect(numbered == fullStops, "\(component) at \(increment.label)")
        }
    }

    // MARK: - The rule as the dial sees it

    /// At the full-stop increment the scale is its own major scale, so every
    /// graduation is numbered — the lens barrel the handoff drew.
    @Test(arguments: components)
    func everyGraduationIsNumberedAtFullStops(_ component: ExposureComponent) {
        let graduations = DialGraduations(component: component, increment: .full)
        #expect(graduations.count == component.scale(for: .full).stops.count)
        #expect((0..<graduations.count).allSatisfy { graduations.isMajor($0) }, "\(component)")
    }

    /// At half and third stops the numbers thin out evenly: the scale opens and
    /// closes on a full stop, and carries exactly one (half) or two (third) bare
    /// ticks between each pair of numbers.
    ///
    /// Even spacing is what the ruler's readability rests on — a run of five
    /// unnumbered ticks somewhere in the middle of the shutter scale would leave
    /// the photographer counting clicks — and it is a property of the hand-written
    /// scales rather than of this type, so it is pinned rather than assumed.
    @Test(arguments: components)
    func theTicksBetweenNumbersAreEvenlySpaced(_ component: ExposureComponent) {
        for (increment, expected) in [(StopIncrement.half, 1), (.third, 2)] {
            let graduations = DialGraduations(component: component, increment: increment)
            let numbered = (0..<graduations.count).filter { graduations.isMajor($0) }

            #expect(numbered.first == 0, "\(component) at \(increment.label) opens on a tick")
            #expect(
                numbered.last == graduations.count - 1,
                "\(component) at \(increment.label) closes on a tick"
            )

            let gaps = zip(numbered, numbered.dropFirst()).map { $1 - $0 - 1 }
            #expect(
                gaps.allSatisfy { $0 == expected },
                "\(component) at \(increment.label): \(gaps) ticks between numbers"
            )
        }
    }

    /// The same duration written two ways is still the same stop: 1/2 s is marked
    /// `1/2` on the full-stop shutter scale and `0.5"` on the third-stop one, so
    /// matching on `PhotographicScale.Stop` — which compares its label too — would
    /// quietly lose it.
    @Test func aStopMarkedTwoWaysIsStillTheSameStop() {
        let thirds = ExposureComponent.shutter.scale(for: .third).stops
        let graduations = DialGraduations(component: .shutter, increment: .third)

        let halfSecond = thirds.firstIndex { $0.label == "0.5\"" }
        #expect(halfSecond != nil)
        #expect(graduations.isMajor(halfSecond ?? -1))

        // …and the label really does differ between the two scales, so this test
        // keeps testing something if one of them is ever re-marked.
        let full = ExposureComponent.shutter.scale(for: .full).stops
        #expect(full.contains { $0.label == "1/2" })
    }

    // MARK: - Compensation

    /// Compensation is numbered at whole stops of bias and ticked at the thirds
    /// between them — the same shape as a photographic scale, applied to the one
    /// dial target that has no `PhotographicScale` to be a member of.
    @Test func compensationIsNumberedAtWholeStops() {
        let stops = (-9...9).map { Double($0) / 3 }
        let graduations = DialGraduations(compensationStops: stops)

        #expect(graduations.count == stops.count)
        for (index, value) in stops.enumerated() {
            #expect(
                graduations.isMajor(index) == (value == value.rounded()),
                "\(value) EV"
            )
        }
        // ±3 EV in whole stops: -3, -2, -1, 0, +1, +2, +3.
        #expect((0..<graduations.count).filter { graduations.isMajor($0) }.count == 7)
    }

    // MARK: - Bounds

    /// The dial draws a clamped window of indices; a bounds slip should cost a
    /// number, not the app.
    @Test func anIndexOffTheScaleIsMinorRatherThanATrap() {
        let graduations = DialGraduations(component: .aperture, increment: .full)
        #expect(graduations.isMajor(-1) == false)
        #expect(graduations.isMajor(graduations.count) == false)
        #expect(DialGraduations(values: [], majorValues: []).isMajor(0) == false)
    }
}
