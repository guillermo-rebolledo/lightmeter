import CoreGraphics
import Testing
@testable import Lightmeter

struct GuidedTourCalloutLayoutTests {
    /// A stand-in callout that reports a fixed height regardless of the proposed
    /// width, so the placement math is exercised in isolation from text wrapping.
    private func fixedHeight(_ height: CGFloat) -> (CGFloat) -> CGFloat {
        { _ in height }
    }

    // MARK: Portrait — the callout sits above or below wide, short targets.

    @Test("Portrait target with room below places the callout below it")
    func portraitPlacesBelow() {
        let bounds = CGRect(x: 0, y: 0, width: 390, height: 844)
        // A short control row near the top: plenty of room below, little above.
        let target = CGRect(x: 40, y: 80, width: 310, height: 44)

        let frame = GuidedTourCalloutLayout.calloutFrame(
            targetFrame: target,
            bounds: bounds,
            measuredHeight: fixedHeight(120)
        )

        #expect(frame.minY >= target.maxY, "Callout should clear the target")
        #expect(bounds.contains(frame), "Callout must stay on screen")
    }

    @Test("Portrait target near the bottom places the callout above it")
    func portraitPlacesAbove() {
        let bounds = CGRect(x: 0, y: 0, width: 390, height: 844)
        let target = CGRect(x: 40, y: 720, width: 310, height: 44)

        let frame = GuidedTourCalloutLayout.calloutFrame(
            targetFrame: target,
            bounds: bounds,
            measuredHeight: fixedHeight(120)
        )

        #expect(frame.maxY <= target.minY, "Callout should sit above the target")
        #expect(bounds.contains(frame), "Callout must stay on screen")
    }

    // MARK: Landscape — tall, edge-hugging targets push the callout to the side.

    @Test("Landscape leading column places the callout to its trailing side")
    func landscapeLeadingColumnPlacesTrailing() {
        let bounds = CGRect(x: 0, y: 0, width: 844, height: 390)
        // The leading control column: tall and hugging the left edge.
        let target = CGRect(x: 16, y: 16, width: 260, height: 358)

        let frame = GuidedTourCalloutLayout.calloutFrame(
            targetFrame: target,
            bounds: bounds,
            measuredHeight: fixedHeight(160)
        )

        #expect(frame.minX >= target.maxX, "Callout should sit right of the column")
        #expect(bounds.contains(frame), "Callout must stay on screen")
        #expect(!frame.intersects(target), "Callout must not cover the target")
    }

    @Test("Landscape trailing dial places the callout to its leading side")
    func landscapeTrailingDialPlacesLeading() {
        let bounds = CGRect(x: 0, y: 0, width: 844, height: 390)
        // The vertical arc dial: tall and hugging the right edge.
        let target = CGRect(x: 784, y: 16, width: 60, height: 358)

        let frame = GuidedTourCalloutLayout.calloutFrame(
            targetFrame: target,
            bounds: bounds,
            measuredHeight: fixedHeight(160)
        )

        #expect(frame.maxX <= target.minX, "Callout should sit left of the dial")
        #expect(bounds.contains(frame), "Callout must stay on screen")
        #expect(!frame.intersects(target), "Callout must not cover the target")
    }

    @Test("Landscape floating readout near the top places the callout below it")
    func landscapeFloatingReadoutPlacesBelow() {
        let bounds = CGRect(x: 0, y: 0, width: 844, height: 390)
        // The EV readout floats at the middle region's top-leading corner.
        let target = CGRect(x: 296, y: 20, width: 120, height: 40)

        let frame = GuidedTourCalloutLayout.calloutFrame(
            targetFrame: target,
            bounds: bounds,
            measuredHeight: fixedHeight(120)
        )

        #expect(frame.minY >= target.maxY, "Short top target leaves room below")
        #expect(bounds.contains(frame), "Callout must stay on screen")
    }

    // MARK: Clamping — the callout never leaves the bounds.

    @Test("Callout stays on screen even when the target sits in a corner")
    func cornerTargetStaysOnScreen() {
        let bounds = CGRect(x: 0, y: 0, width: 844, height: 390)
        let target = CGRect(x: 800, y: 4, width: 40, height: 40)

        let frame = GuidedTourCalloutLayout.calloutFrame(
            targetFrame: target,
            bounds: bounds,
            measuredHeight: fixedHeight(140)
        )

        #expect(bounds.contains(frame), "Callout must stay on screen")
    }
}
