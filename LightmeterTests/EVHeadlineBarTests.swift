import SwiftUI
import Testing
@testable import Lightmeter

/// The EV headline bar as laid out: what it does when the photographer touches
/// it, and what it must never do while they are reading it.
///
/// The bar is pinned above a live scene the photographer is composing in, and its
/// two ends are controls they reach for without looking. So the assertions here
/// are mostly *absence* assertions — nothing moves — driven through a real
/// `MeterViewModel` rather than through hand-picked strings, because the values
/// that would move it are the ones the meter actually produces.
@MainActor
struct EVHeadlineBarTests {
    /// The narrowest iPhone the deployment target reaches — the 375pt SE, the
    /// smallest screen iOS 17 runs on — minus the bar's inset from both screen
    /// edges. The tightest realistic proposal, where the caption (the widest thing
    /// in the bar) has the least slack.
    private static let barWidth = 375 - 2 * PortraitMeterLayout.panelInset

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

    /// The size the bar resolves to at a fixed width — what a floating panel
    /// stretches to, and therefore what must not move.
    private func barSize(_ model: MeterViewModel) -> CGSize {
        let host = UIHostingController(
            rootView: EVHeadlineBar(model: model).frame(width: Self.barWidth)
        )
        host.view.setNeedsLayout()
        host.view.layoutIfNeeded()
        return host.sizeThatFits(
            in: CGSize(width: Self.barWidth, height: .greatestFiniteMagnitude)
        )
    }

    // MARK: - Nothing moves

    /// Freezing swaps an open padlock for a closed one at the bar's leading end.
    /// The two glyphs are not the same width, so without a frame around them the
    /// whole bar would shuffle as the photographer holds a reading — which is the
    /// one moment they are least able to look at the screen.
    @Test func freezingNeverResizesTheBar() async {
        let model = await meteringModel()
        let baseline = barSize(model)
        #expect(baseline.height > 0)

        model.toggleFreeze()
        #expect(model.isFrozen)
        #expect(barSize(model) == baseline)

        model.toggleFreeze()
        #expect(model.isFrozen == false)
        #expect(barSize(model) == baseline)
    }

    /// Every value in the bar changes width as the light and the settings move:
    /// `EV 9.5` to `EV -1.3`, `1/8000` to `30"`, `ISO 100` to `ISO 12800`. None of
    /// them may resize the bar around them — they are one scale-to-fit line each,
    /// and the trailing pair holds its own column.
    @Test func noValueTheMeterProducesResizesTheBar() async {
        let model = await meteringModel()
        let baseline = barSize(model)

        // Both priority modes, so the solved leg is a shutter in one and an
        // f-number in the other, and the widest and narrowest of each.
        for mode in [PriorityMode.aperturePriority, .shutterPriority] {
            model.setMode(mode)
            for iso in [100.0, 12800.0] {
                model.setISO(iso)
                for aperture in [1.4, 22.0] {
                    model.setAperture(aperture)
                    for shutter in [1.0 / 8000, 30.0] {
                        model.setShutter(shutter)
                        #expect(
                            barSize(model) == baseline,
                            "\(mode) ISO \(iso) f/\(aperture) \(shutter)s"
                        )
                    }
                }
            }
        }
    }

    /// Tapping ISO rings its outline. The ring is a stroke inside the control's
    /// own bounds — the same vocabulary, and the same no-cost geometry, the
    /// exposure chips use — so binding the dial cannot nudge the bar.
    @Test func bindingTheDialToISONeverResizesTheBar() async {
        let model = await meteringModel()
        let baseline = barSize(model)

        model.selectChip(.iso)
        #expect(model.boundComponent == .iso)
        #expect(barSize(model) == baseline)
    }

    // MARK: - What the controls do

    /// The bar's one tappable value: ISO points the ruler dial at the ISO scale,
    /// through the same entry point a chip tap uses. ISO is never the solved leg,
    /// so this is always available.
    @Test func tappingISOPointsTheDialAtTheISOScale() async {
        let model = await meteringModel()
        model.selectChip(.aperture)
        #expect(model.boundComponent == .aperture)

        model.selectChip(.iso)

        #expect(model.boundComponent == .iso)
        #expect(model.dialCaption == ExposureComponent.iso.caption)
        #expect(model.dialLabels.isEmpty == false)
    }

    /// …in both priority modes, since which leg is solved changes underneath it.
    @Test func ISOIsAlwaysDialableWhicheverLegIsSolved() async {
        let model = await meteringModel()

        for mode in [PriorityMode.aperturePriority, .shutterPriority] {
            model.setMode(mode)
            #expect(model.isEditable(.iso), "\(mode)")
            model.selectChip(.iso)
            #expect(model.boundComponent == .iso, "\(mode)")
        }
    }

    /// The padlock still drives freeze from its new home, and reports the state
    /// its glyph shows sighted users.
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

    // MARK: - The layout budget

    /// Four things compete for one row. At every size the row survives, this
    /// checks it still balances: both flexible blocks at their shrink floors,
    /// plus the chrome that cannot compress at all, inside the narrowest bar.
    ///
    /// It exists because the failure it catches is silent. Over-subscribe the row
    /// and nothing wraps, clips, or crashes — SwiftUI simply squeezes the
    /// flexible column, and the largest number on the screen becomes `E…`. That
    /// is what the first draft of this bar did at `accessibility3`.
    @Test(arguments: DynamicTypeSize.allCases.filter { EVHeadlineBar.Arrangement(at: $0) == .row })
    func theRowFitsTheNarrowestBarAtEverySizeThatKeepsIt(_ size: DynamicTypeSize) async {
        let model = await meteringModel()
        let readout = EVHeadlineReadout(ev: model.ev, triangle: model.triangle)

        let headline = idealWidth(EVHeadlineValue(readout: readout), at: size)
        let trailing = idealWidth(
            EVHeadlineTrailingPair(
                readout: readout, isDialBoundToISO: false, onSelectISO: {}
            ),
            at: size
        )
        #expect(trailing > 0)
        let padlock = idealWidth(
            FreezeButton(isFrozen: false, canFreeze: true, onToggle: {}, hasSurface: false),
            at: size
        )

        let needed = headline * EVHeadlineValue.minimumScale
            + trailing * EVHeadlineTrailingPair.minimumScale
            + padlock
            + MeterSettingsGear.touchTarget
            + 3 * EVHeadlineBar.itemSpacing
            + 2 * EVHeadlineBar.horizontalPadding

        #expect(
            needed <= Self.barWidth,
            """
            \(size): the row needs \(needed)pt of \(Self.barWidth)pt — \
            headline \(headline), trailing \(trailing), padlock \(padlock)
            """
        )
    }

    /// …and above those sizes the row is abandoned rather than crushed.
    ///
    /// `EXPOSURE VALUE @ ISO 100` at an accessibility size is wider than any
    /// iPhone on its own, so no distribution of one row works: the caption cannot
    /// both hold the ISO 100 qualifier (ADR-0001) and stay on a line with the
    /// value, the padlock, the trailing pair, and the gear. The reflow is pinned
    /// as a rule rather than left to a measurement, because a layout that decides
    /// this for itself decides it from *ideal* widths and abandons the row at the
    /// default size too — where the row is exactly what the design wants.
    @Test func theBarReflowsExactlyAtTheAccessibilitySizes() {
        for size in DynamicTypeSize.allCases {
            let expected: EVHeadlineBar.Arrangement = size.isAccessibilitySize ? .stacked : .row
            #expect(EVHeadlineBar.Arrangement(at: size) == expected, "\(size)")
        }
        #expect(EVHeadlineBar.Arrangement(at: .large) == .row)
        #expect(EVHeadlineBar.Arrangement(at: .accessibility1) == .stacked)
        #expect(EVHeadlineBar.Arrangement(at: AppTypography.maximumDynamicTypeSize) == .stacked)
    }

    /// One view's ideal width at a given text size.
    private func idealWidth(_ view: some View, at size: DynamicTypeSize) -> CGFloat {
        let host = UIHostingController(rootView: view.dynamicTypeSize(size))
        host.view.setNeedsLayout()
        host.view.layoutIfNeeded()
        let unbounded = CGFloat.greatestFiniteMagnitude
        return host.sizeThatFits(in: CGSize(width: unbounded, height: unbounded)).width
    }

    // MARK: - The ends are targets

    /// Both ends meet Apple's 44pt minimum. The padlock scales its target with
    /// Dynamic Type; the gear holds a fixed frame. Measured rather than asserted
    /// against the constants, because what matters is the frame that ends up
    /// under the thumb.
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

    // MARK: - VoiceOver

    /// The three values are separate elements with distinct names, and the ISO
    /// control carries a hint saying what the tap does. Pinned on the readout the
    /// view renders from, so the words are testable without walking the
    /// accessibility tree.
    @Test func theBarsThreeValuesAreSeparatelyLabelled() async {
        let model = await meteringModel()
        let readout = EVHeadlineReadout(ev: model.ev, triangle: model.triangle)

        let labels = [
            readout.accessibilityLabel,
            readout.solvedAccessibilityLabel,
            readout.isoAccessibilityLabel,
        ]
        #expect(labels.allSatisfy { $0.isEmpty == false })
        #expect(Set(labels).count == labels.count)

        let values = [
            readout.accessibilityValue,
            readout.solvedAccessibilityValue,
            readout.isoValue,
        ]
        #expect(values.allSatisfy { $0.isEmpty == false })

        #expect(EVHeadlineReadout.isoAccessibilityHint.isEmpty == false)
    }
}
