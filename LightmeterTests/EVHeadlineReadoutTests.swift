import Foundation
import Testing
@testable import Lightmeter

/// What the EV headline bar says, pinned without a view.
///
/// The bar is the screen's largest readout, so the two things most worth holding
/// still are what its label claims and what its number does. Both are ADR-0001:
/// EV is a property of the *scene*, quoted at ISO 100, and it is labelled as such
/// close enough to the number that the ISO readout inches away cannot be mistaken
/// for the one it is quoted at.
struct EVHeadlineReadoutTests {
    private let sunny = ExposureEngine.solvedTriangle(
        mode: .aperturePriority, evAtISO100: 15, iso: 100, aperture: 16, shutter: 1.0 / 125
    )

    // MARK: - The label

    /// The handoff labels the value bare `EXPOSURE VALUE` while placing an ISO
    /// readout in the same bar. That reads as EV-at-that-ISO and is wrong, so the
    /// qualifier is part of the caption rather than an optional decoration.
    @Test func theCaptionNamesTheISOTheValueIsQuotedAt() {
        let readout = EVHeadlineReadout(ev: 12.34, triangle: sunny)

        #expect(readout.caption.contains("ISO 100"))
        #expect(readout.caption == "Exposure value @ ISO 100")
    }

    /// …and it says so however the photographer's own ISO is set, because the
    /// caption is about the reference, not about their film stock.
    @Test func theCaptionSaysISO100EvenWhenTheMeterIsSetToAnotherISO() {
        let atISO400 = ExposureEngine.solvedTriangle(
            mode: .aperturePriority, evAtISO100: 15, iso: 400, aperture: 16, shutter: 1.0 / 500
        )
        let readout = EVHeadlineReadout(ev: 12.34, triangle: atISO400)

        // The reference stays ISO 100 even though the meter is set to ISO 400.
        #expect(readout.caption.contains("ISO 100"))
        #expect(atISO400.iso.label == "400")
    }

    // MARK: - The value

    /// One decimal, and the `EV` prefix the app has always read it with.
    @Test(arguments: [
        (12.34, "EV 12.3"),
        (15.0, "EV 15.0"),
        (3.66, "EV 3.7"),
        (-1.28, "EV -1.3"),
    ])
    func theValueIsTheSceneReadingToOneDecimal(ev: Double, expected: String) {
        #expect(EVHeadlineReadout(ev: ev, triangle: sunny).value == expected)
    }

    /// Before the first reading there is no light to report. The bar shows the
    /// app's em-dash placeholder rather than a stale or invented number — and says
    /// it in words to VoiceOver, for which a dash is meaningless.
    @Test func aPendingReadingShowsThePlaceholderAndIsSpokenInWords() {
        let pending = ExposureEngine.solvedTriangle(
            mode: .aperturePriority, evAtISO100: nil, iso: 100, aperture: 8, shutter: 1.0 / 125
        )
        let readout = EVHeadlineReadout(ev: nil, triangle: pending)

        #expect(readout.value == "EV \(ExposureTriangle.pendingMarking)")
        #expect(readout.solvedValue == ExposureTriangle.pendingMarking)
        #expect(readout.accessibilityValue == "Pending")
        #expect(readout.solvedAccessibilityValue == "Pending")
    }

    // MARK: - The trailing pair

    /// The solved leg is whichever leg the engine answered for, marked as a camera
    /// marks it — so flipping priority changes both the value and the leg it names.
    @Test func theSolvedLegFollowsThePriorityMode() {
        let aperturePriority = EVHeadlineReadout(ev: 15, triangle: sunny)
        #expect(aperturePriority.solvedCaption == "Shutter")
        #expect(aperturePriority.solvedValue == sunny.marking(of: .shutter))

        let shutterPriority = ExposureEngine.solvedTriangle(
            mode: .shutterPriority, evAtISO100: 15, iso: 100, aperture: 16, shutter: 1.0 / 125
        )
        let readout = EVHeadlineReadout(ev: 15, triangle: shutterPriority)
        #expect(readout.solvedCaption == "Aperture")
        #expect(readout.solvedValue.hasPrefix("f/"))
    }

    // MARK: - VoiceOver

    /// Two values, two voices. A sighted reader tells them apart by size, accent,
    /// and position; a VoiceOver user has only the words, so each element names
    /// itself and the EV value carries the qualifier its caption gives sighted
    /// readers. (ISO left the bar for the mode row, so it is no longer among them.)
    @Test func eachValueSpeaksItsOwnNameAndTheEVValueCarriesTheQualifier() {
        let readout = EVHeadlineReadout(ev: 12.34, triangle: sunny)

        #expect(readout.accessibilityLabel == "Scene exposure value")
        #expect(readout.accessibilityValue == "EV 12.3 at ISO 100")
        #expect(readout.solvedAccessibilityLabel == "Shutter")
        #expect(readout.solvedAccessibilityValue == sunny.marking(of: .shutter))

        let spoken = [
            readout.accessibilityLabel,
            readout.solvedAccessibilityLabel,
        ]
        #expect(Set(spoken).count == spoken.count, "two elements answer to the same name")
    }
}

/// ADR-0001, driven through the live view-model: the headline moves when the
/// light moves, and at no other time.
///
/// The per-value tests above pin the formatting; this pins the *meaning*. A meter
/// whose headline jumps because the photographer changed ISO has stopped being an
/// instrument, and the bar puts an ISO readout inches from the number — which is
/// exactly the arrangement that makes the mistake tempting.
@MainActor
struct EVHeadlineReadoutInvarianceTests {
    private func meteringModel() async -> MeterViewModel {
        let source = FakeLightSource()
        let model = MeterViewModel(source: source)
        await model.start()
        source.emit(LightReading(iso: 100, exposureDuration: 1.0 / 128.0, aperture: 16))
        for _ in 0..<10_000 where model.ev == nil {
            await Task.yield()
        }
        #expect(model.ev != nil, "the fake source never produced a reading")
        return model
    }

    private func headline(_ model: MeterViewModel) -> String {
        EVHeadlineReadout(ev: model.ev, triangle: model.triangle).value
    }

    @Test func theHeadlineIsUnmovedByEverySettingThePhotographerCanChange() async {
        let model = await meteringModel()
        let baseline = headline(model)

        model.setISO(1600)
        #expect(headline(model) == baseline, "ISO moved the headline")

        model.setAperture(2.8)
        #expect(headline(model) == baseline, "aperture moved the headline")

        model.setShutter(1.0 / 30)
        #expect(headline(model) == baseline, "shutter moved the headline")

        model.setCompensation(2)
        #expect(headline(model) == baseline, "compensation moved the headline")

        model.setMode(.shutterPriority)
        #expect(headline(model) == baseline, "priority moved the headline")

        model.selectChip(.aperture)
        #expect(headline(model) == baseline, "claiming a leg moved the headline")
    }

    /// The other half of the same claim: it *does* move when the light does.
    /// Without this the test above would pass on a headline hard-coded to a
    /// constant.
    @Test func theHeadlineMovesWhenTheLightDoes() async {
        let source = FakeLightSource()
        let model = MeterViewModel(source: source)
        await model.start()
        source.emit(LightReading(iso: 100, exposureDuration: 1.0 / 128.0, aperture: 16))
        for _ in 0..<10_000 where model.ev == nil {
            await Task.yield()
        }
        let bright = headline(model)

        // Four stops darker, from the same ISO and aperture.
        source.emit(LightReading(iso: 100, exposureDuration: 1.0 / 8.0, aperture: 16))
        for _ in 0..<10_000 where headline(model) == bright {
            await Task.yield()
        }
        #expect(headline(model) != bright)
    }
}
