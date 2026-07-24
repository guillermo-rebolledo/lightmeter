import SwiftUI
import Testing
@testable import Lightmeter

/// The demoted EV reference strip at the top of the settings-first portrait meter.
///
/// EV is no longer the hero — the exposure chips are — but the strip is still
/// pinned above a live scene the photographer is composing in, and its two ends
/// (the freeze padlock and the settings gear) are controls they reach for without
/// looking. So the assertions here are mostly *absence* assertions — nothing
/// moves — driven through a real `MeterViewModel`, plus the ADR-0001 invariant the
/// strip inherits from the bar it replaces: the ISO-100 reference stays visible
/// and spoken.
@MainActor
struct EVReferenceStripTests {
    /// The narrowest iPhone the deployment target reaches — the 375pt SE — minus
    /// the strip's inset from both screen edges. The tightest realistic proposal.
    private static let stripWidth = 375 - 2 * PortraitMeterLayout.panelInset

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

    /// The size the strip resolves to at a fixed width — what a floating panel
    /// stretches to, and therefore what must not move.
    private func stripSize(_ model: MeterViewModel) -> CGSize {
        let host = UIHostingController(
            rootView: EVReferenceStrip(model: model).frame(width: Self.stripWidth)
        )
        host.view.setNeedsLayout()
        host.view.layoutIfNeeded()
        return host.sizeThatFits(
            in: CGSize(width: Self.stripWidth, height: .greatestFiniteMagnitude)
        )
    }

    // MARK: - Nothing moves

    /// Freezing swaps an open padlock for a closed one at the strip's leading end.
    /// The two glyphs are not the same width, so without a fixed frame around them
    /// the strip would shuffle while the photographer holds a reading.
    @Test func freezingNeverResizesTheStrip() async {
        let model = await meteringModel()
        let baseline = stripSize(model)
        #expect(baseline.height > 0)

        model.toggleFreeze()
        #expect(model.isFrozen)
        #expect(stripSize(model) == baseline)

        model.toggleFreeze()
        #expect(model.isFrozen == false)
        #expect(stripSize(model) == baseline)
    }

    /// The EV value changes width as the light moves — `EV 9.5` to `EV -1.3` — and
    /// changing the settings re-solves the triangle underneath it. None of it may
    /// resize the strip: the value is one scale-to-fit line.
    @Test func noReadingTheMeterProducesResizesTheStrip() async {
        let model = await meteringModel()
        let baseline = stripSize(model)

        for mode in [PriorityMode.aperturePriority, .shutterPriority] {
            model.setMode(mode)
            for iso in [100.0, 12800.0] {
                model.setISO(iso)
                for aperture in [1.4, 22.0] {
                    model.setAperture(aperture)
                    for shutter in [1.0 / 8000, 30.0] {
                        model.setShutter(shutter)
                        #expect(
                            stripSize(model) == baseline,
                            "\(mode) ISO \(iso) f/\(aperture) \(shutter)s"
                        )
                    }
                }
            }
        }
    }

    /// The first reading arriving is the other no-shift case the constraint names:
    /// the strip is on screen before metering resolves, showing the em-dash
    /// placeholder, and the scene's first EV replacing it must not resize it. The
    /// value is one scale-to-fit line in both states, so the pending-to-live jump
    /// is a pure repaint.
    @Test func theFirstReadingNeverResizesTheStrip() async {
        let source = FakeLightSource()
        let model = MeterViewModel(source: source)
        await model.start()

        // Pending: metering has begun, but no reading has arrived yet.
        #expect(model.ev == nil)
        let pending = stripSize(model)
        #expect(pending.height > 0)

        source.emit(LightReading(iso: 100, exposureDuration: 1.0 / 128.0, aperture: 16))
        for _ in 0..<10_000 where model.ev == nil {
            await Task.yield()
        }
        #expect(model.ev != nil)

        #expect(stripSize(model) == pending)
    }

    // MARK: - The ends still work and are targets

    /// The padlock still drives freeze from its home on the strip, and reports the
    /// state its glyph shows sighted users.
    @Test func thePadlockStillHoldsAndReleasesTheReading() async {
        let model = await meteringModel()
        #expect(FreezeButton.LockState(isFrozen: model.isFrozen) == .live)

        model.toggleFreeze()
        #expect(model.isFrozen)
        #expect(FreezeButton.LockState(isFrozen: model.isFrozen) == .held)

        model.toggleFreeze()
        #expect(model.isFrozen == false)
        #expect(FreezeButton.LockState(isFrozen: model.isFrozen) == .live)
    }

    /// Both ends meet Apple's 44pt minimum, as they did on the old bar.
    @Test func thePadlockAndTheGearAreBothFullTouchTargets() {
        let padlock = UIHostingController(
            rootView: FreezeButton(
                isFrozen: false, canFreeze: true, onToggle: {}, hasSurface: false
            )
        ).view.intrinsicContentSize
        #expect(padlock.width >= 44)
        #expect(padlock.height >= 44)

        #expect(MeterSettingsGear.touchTarget >= 44)
    }

    // MARK: - ADR-0001: the reference stays visible and spoken

    /// The strip keeps the ISO-100 qualifier the headline bar carried (ADR-0001):
    /// the reference is drawn beside the number, so `EV 12.3` can't be read as
    /// "EV at whatever ISO I set", and it is spoken too.
    @Test func theReferenceIsVisibleAndSpoken() async {
        let model = await meteringModel()
        let readout = EVHeadlineReadout(ev: model.ev, triangle: model.triangle)

        // Drawn: the "@ ISO 100" reference is part of the readout's own text.
        #expect(EVReferenceReadout.reference.contains("ISO 100"))
        // Spoken: VoiceOver hears the sensitivity, not a bare number.
        #expect(readout.accessibilityValue.contains("ISO 100"))
        #expect(readout.accessibilityLabel.isEmpty == false)
    }

    /// The caption names the number as a measurement of the scene, not a camera
    /// setting — the wording that stops the reference reading as a stuck ISO dial.
    @Test func theCaptionNamesTheSceneNotASetting() {
        #expect(EVReferenceReadout.caption.isEmpty == false)
        // It must not imply the photographer's own ISO; the reference line owns
        // the ISO-100 standard instead.
        #expect(EVReferenceReadout.caption.contains("ISO") == false)
    }
}
