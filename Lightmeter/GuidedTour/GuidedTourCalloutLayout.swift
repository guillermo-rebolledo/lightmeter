import SwiftUI

/// Positions the guided-tour callout next to its spotlight target, keeping the
/// card on screen and clear of the target it explains.
///
/// The callout prefers the **vertical** axis — above or below the target,
/// spanning the width band — which reads naturally for the wide, short control
/// rows of portrait. When a target is *tall and edge-hugging* (the landscape
/// leading control column or trailing vertical dial), there is no vertical room
/// to clear it, so the callout moves to the target's **side** instead of
/// clamping into an overlap. Every result is clamped to the bounds.
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

        let frame = Self.calloutFrame(
            targetFrame: targetFrame,
            bounds: bounds,
            measuredHeight: { width in
                callout.dimensions(
                    in: ProposedViewSize(width: width, height: nil)
                ).height
            }
        )

        callout.place(
            at: CGPoint(x: frame.minX, y: frame.minY),
            anchor: .topLeading,
            proposal: ProposedViewSize(frame.size)
        )
    }

    /// Pure placement geometry, split out so the edge cases can be unit-tested
    /// without a live view hierarchy. `measuredHeight` reports the callout's
    /// height for a proposed width (text wraps taller when narrower).
    static func calloutFrame(
        targetFrame: CGRect,
        bounds: CGRect,
        measuredHeight: (CGFloat) -> CGFloat,
        maxWidth: CGFloat = 320,
        minSideWidth: CGFloat = 200,
        margin: CGFloat = 20,
        gap: CGFloat = 16
    ) -> CGRect {
        let maximumHeight = max(bounds.height - (margin * 2), 0)

        let roomAbove = targetFrame.minY - bounds.minY
        let roomBelow = bounds.maxY - targetFrame.maxY
        let roomLeading = targetFrame.minX - bounds.minX
        let roomTrailing = bounds.maxX - targetFrame.maxX

        // Vertical candidate: the callout spans the full width band and sits in
        // whichever of above/below has more room.
        let verticalWidth = min(max(bounds.width - (margin * 2), 0), maxWidth)
        let verticalHeight = min(measuredHeight(verticalWidth), maximumHeight)
        let verticalRoom = max(roomAbove, roomBelow)
        let verticalFits = verticalRoom >= verticalHeight + gap + margin

        // A tall, edge-hugging target (landscape column or dial) leaves no
        // vertical room; place beside it if a side offers a readable width.
        let sideRoom = max(roomLeading, roomTrailing)
        let sideWidth = min(max(sideRoom - gap - margin, 0), maxWidth)
        let sideFits = sideWidth >= minSideWidth

        if verticalFits || !sideFits {
            let x = clamp(
                targetFrame.midX - (verticalWidth / 2),
                min: bounds.minX + margin,
                max: bounds.maxX - margin - verticalWidth
            )
            let proposedY = roomAbove > roomBelow
                ? targetFrame.minY - gap - verticalHeight
                : targetFrame.maxY + gap
            let y = clamp(
                proposedY,
                min: bounds.minY + margin,
                max: bounds.maxY - margin - verticalHeight
            )
            return CGRect(x: x, y: y, width: verticalWidth, height: verticalHeight)
        }

        let sideHeight = min(measuredHeight(sideWidth), maximumHeight)
        let placeTrailing = roomTrailing >= roomLeading
        let proposedX = placeTrailing
            ? targetFrame.maxX + gap
            : targetFrame.minX - gap - sideWidth
        let x = clamp(
            proposedX,
            min: bounds.minX + margin,
            max: bounds.maxX - margin - sideWidth
        )
        let y = clamp(
            targetFrame.midY - (sideHeight / 2),
            min: bounds.minY + margin,
            max: bounds.maxY - margin - sideHeight
        )
        return CGRect(x: x, y: y, width: sideWidth, height: sideHeight)
    }

    /// Clamps `value` into `[min, max]`, tolerating an inverted range (when the
    /// callout is wider or taller than the bounds allow) by pinning to `max`.
    private static func clamp(_ value: CGFloat, min lower: CGFloat, max upper: CGFloat) -> CGFloat {
        Swift.min(Swift.max(value, lower), upper)
    }
}
