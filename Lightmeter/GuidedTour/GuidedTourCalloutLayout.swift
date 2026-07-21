import SwiftUI

struct GuidedTourCalloutLayout: Layout {
    let targetFrame: CGRect

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        proposal.replacingUnspecifiedDimensions()
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        guard let callout = subviews.first else { return }

        let margin = 20.0
        let gap = 16.0
        let width = min(max(bounds.width - (margin * 2), 0), 320)
        let dimensions = callout.dimensions(
            in: ProposedViewSize(width: width, height: nil)
        )
        let maximumHeight = max(bounds.height - (margin * 2), 0)
        let calloutSize = CGSize(
            width: width,
            height: min(dimensions.height, maximumHeight)
        )
        let x = min(
            max(targetFrame.midX - (width / 2), bounds.minX + margin),
            bounds.maxX - margin - width
        )
        let roomAbove = targetFrame.minY - bounds.minY
        let roomBelow = bounds.maxY - targetFrame.maxY
        let proposedY = if roomAbove > roomBelow {
            targetFrame.minY - gap - calloutSize.height
        } else {
            targetFrame.maxY + gap
        }
        let y = min(
            max(proposedY, bounds.minY + margin),
            bounds.maxY - margin - calloutSize.height
        )

        callout.place(
            at: CGPoint(x: x, y: y),
            anchor: .topLeading,
            proposal: ProposedViewSize(calloutSize)
        )
    }
}
