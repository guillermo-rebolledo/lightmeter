import SwiftUI

/// A row whose subviews take widths **proportional to `weights`**, with `spacing`
/// between each pair.
///
/// The mode row is two glass tracks — three cells (aperture · shutter · ISO) then
/// two (average · spot) — and every one of the five cells must read as the same
/// width, so the row is one instrument rather than two mismatched strips. Two
/// equal halves would divide the wider track's width among three cells and the
/// narrower's among two, making the left cells smaller — and the longest labels
/// land there. Splitting the row 3 : 2 instead gives every cell the same share.
///
/// Sibling to ``EqualWidthRow``: that one divides a track's width *equally* among
/// its cells; this one divides the *row's* width among the tracks *by weight*, so
/// the two together land equal cells across separately-padded tracks.
struct WeightedRow: Layout {
    /// One weight per subview, in order. A count that doesn't match the subviews
    /// degrades to equal columns rather than crashing.
    var weights: [CGFloat]

    /// The gutter between adjacent columns.
    var spacing: CGFloat

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout Void
    ) -> CGSize {
        guard !subviews.isEmpty else { return .zero }
        let widths = columnWidths(for: proposal, subviews: subviews)
        let height = zip(subviews, widths).reduce(CGFloat.zero) { tallest, pair in
            let (subview, width) = pair
            let size = subview.sizeThatFits(
                ProposedViewSize(width: width, height: proposal.height)
            )
            return max(tallest, size.height)
        }
        let total = widths.reduce(0, +) + spacing * CGFloat(subviews.count - 1)
        return CGSize(width: total, height: height)
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout Void
    ) {
        guard !subviews.isEmpty else { return }
        let widths = columnWidths(
            for: ProposedViewSize(width: bounds.width, height: bounds.height),
            subviews: subviews
        )
        var x = bounds.minX
        for (subview, width) in zip(subviews, widths) {
            subview.place(
                at: CGPoint(x: x, y: bounds.minY),
                proposal: ProposedViewSize(width: width, height: bounds.height)
            )
            x += width + spacing
        }
    }

    /// Each column's width. With a width proposed, the available space (minus the
    /// gutters) split by weight; unproposed — the ideal-size query — each subview's
    /// own ideal width, so the row still reports a sensible intrinsic size.
    private func columnWidths(for proposal: ProposedViewSize, subviews: Subviews) -> [CGFloat] {
        guard let width = proposal.width else {
            return subviews.map { $0.sizeThatFits(.unspecified).width }
        }
        let effective = effectiveWeights(count: subviews.count)
        let totalWeight = effective.reduce(0, +)
        guard totalWeight > 0 else { return Array(repeating: 0, count: subviews.count) }
        let gutters = spacing * CGFloat(subviews.count - 1)
        let available = max(0, width - gutters)
        return effective.map { available * $0 / totalWeight }
    }

    /// The weights matched to the subview count: the given weights when they line
    /// up, otherwise equal columns — a safe fall-back rather than an index trap.
    private func effectiveWeights(count: Int) -> [CGFloat] {
        weights.count == count ? weights : Array(repeating: 1, count: count)
    }
}
