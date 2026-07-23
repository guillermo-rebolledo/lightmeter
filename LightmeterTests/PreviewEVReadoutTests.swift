import CoreGraphics
import Testing
@testable import Lightmeter

/// EV's new home: the preview layer. The one piece of real logic is deciding
/// *whether* EV shows and *where* — an inline badge on the spot reticle, or the
/// quiet secondary label average metering falls back to. Pure over
/// `pattern`/`spot`/`ev`, so — like `SolvedLegReadout` — it's tested without a
/// view.
struct PreviewEVReadoutTests {
    // MARK: - Spot: the badge at the metered point

    /// Spot metering with a placed point reads local brightness right where the
    /// photographer is pointing, so EV rides the reticle as an inline badge.
    @Test func spotWithAPlacedPointBadgesTheReticle() {
        let readout = PreviewEVReadout(pattern: .spot, spot: .frameCenter, ev: 12.34)

        #expect(readout?.placement == .reticleBadge)
        #expect(readout?.value == "EV 12.3")
        #expect(readout?.badgeValue == "EV 12.3")
        // The badge case is *not* the secondary label — only one of the two ever
        // renders, and the views select on exactly these.
        #expect(readout?.secondaryValue == nil)
    }

    /// No spot placed means there is no reticle to badge, so nothing is shown at
    /// a point the photographer never chose.
    @Test func spotWithNoPlacedPointShowsNothing() {
        #expect(PreviewEVReadout(pattern: .spot, spot: nil, ev: 12.34) == nil)
    }

    // MARK: - Average: no reticle, a quiet label instead

    /// Average metering measures the whole frame, so EV is a quiet secondary
    /// label — never a badge, which would imply a point was being measured.
    @Test func averageShowsTheQuietSecondaryLabel() {
        let readout = PreviewEVReadout(pattern: .average, spot: nil, ev: 12.34)

        #expect(readout?.placement == .secondaryLabel)
        #expect(readout?.value == "EV 12.3")
        #expect(readout?.secondaryValue == "EV 12.3")
        #expect(readout?.badgeValue == nil)
    }

    /// A spot left over from earlier spot metering doesn't resurrect the badge:
    /// the pattern alone decides, so switching back to average can't leave a
    /// point-shaped readout on a whole-frame read.
    @Test func averageIgnoresALeftoverSpot() {
        let readout = PreviewEVReadout(pattern: .average, spot: CGPoint(x: 0.2, y: 0.8), ev: 12.34)

        #expect(readout?.placement == .secondaryLabel)
    }

    // MARK: - Before the first reading

    /// With no EV yet there is nothing to present in either pattern — the
    /// readout is absent rather than showing a placeholder over the frame.
    @Test func noReadingShowsNothingInEitherPattern() {
        #expect(PreviewEVReadout(pattern: .spot, spot: .frameCenter, ev: nil) == nil)
        #expect(PreviewEVReadout(pattern: .average, spot: nil, ev: nil) == nil)
    }

    // MARK: - The value presented

    /// EV is presented to one decimal — the precision the EV@ISO100 readout this
    /// replaces used — rounded rather than truncated, and signed when the scene
    /// is darker than EV 0.
    @Test func evIsPresentedToOneDecimal() {
        #expect(PreviewEVReadout(pattern: .average, spot: nil, ev: 15)?.value == "EV 15.0")
        #expect(PreviewEVReadout(pattern: .average, spot: nil, ev: 3.66)?.value == "EV 3.7")
        #expect(PreviewEVReadout(pattern: .average, spot: nil, ev: -1.28)?.value == "EV -1.3")
    }

    /// Spoken, "EV 12.3" is a bare number: VoiceOver gets the reference the
    /// glance-level badge leaves implicit — EV is always at ISO 100.
    @Test func voiceOverHearsWhatTheEVIsMeasuredAt() {
        let spoken = PreviewEVReadout(pattern: .spot, spot: .frameCenter, ev: 12.34)?.accessibilityValue

        #expect(spoken == "EV 12.3 at ISO 100")
    }

    /// The badge and the label say *which* read they describe — a spot reading
    /// and a whole-frame reading are different measurements, and only the
    /// reticle's position distinguishes them visually.
    @Test func eachPlacementNamesTheReadItDescribes() {
        let badge = PreviewEVReadout(pattern: .spot, spot: .frameCenter, ev: 12.34)
        let label = PreviewEVReadout(pattern: .average, spot: nil, ev: 12.34)

        #expect(badge?.accessibilityLabel == "Spot exposure value")
        #expect(label?.accessibilityLabel == "Scene exposure value")
    }
}

/// The badge at the view-model seam: it tracks the pattern and spot the
/// photographer actually sets, driven by a fake source with no camera.
@MainActor
struct PreviewEVReadoutViewModelTests {
    /// Waits for `predicate` to hold, yielding to let the metering task run.
    private func waitUntil(
        _ predicate: () -> Bool,
        sourceLocation: SourceLocation = #_sourceLocation
    ) async {
        for _ in 0..<10_000 {
            if predicate() { return }
            await Task.yield()
        }
        Issue.record("Condition never became true", sourceLocation: sourceLocation)
    }

    private func readout(_ model: MeterViewModel) -> PreviewEVReadout? {
        PreviewEVReadout(pattern: model.pattern, spot: model.spot, ev: model.ev)
    }

    /// The default (average) meter shows the quiet label; placing a spot moves
    /// EV onto the reticle, and switching back to average retires the badge.
    @Test func evMovesToTheReticleWhenAScopeIsMeteredAndBackAgain() async {
        let source = FakeLightSource()
        let model = MeterViewModel(source: source)
        await model.start()

        // Sunny 16 → EV 15.
        source.emit(LightReading(iso: 100, exposureDuration: 1.0 / 128.0, aperture: 16))
        await waitUntil { model.ev != nil }

        #expect(readout(model)?.placement == .secondaryLabel)

        model.placeSpot(at: CGPoint(x: 0.25, y: 0.75))
        #expect(readout(model)?.placement == .reticleBadge)
        #expect(readout(model)?.value == "EV 15.0")

        model.setPattern(.average)
        #expect(readout(model)?.placement == .secondaryLabel)
    }

    /// Nothing is shown until the meter has read the scene, in either pattern —
    /// so the badge can never appear on a reticle with no measurement behind it.
    @Test func nothingIsShownBeforeTheFirstReading() async {
        let source = FakeLightSource()
        let model = MeterViewModel(source: source)
        await model.start()

        #expect(readout(model) == nil)

        model.setPattern(.spot)
        #expect(readout(model) == nil)
    }
}
