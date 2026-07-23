import SwiftUI

/// A single row whose subviews all get **exactly** the same width.
///
/// `HStack` can't promise this. It hands each flexible child an equal share only
/// while every child's *minimum* width fits inside that share; a child with a wide
/// minimum (a long shutter label like `1/8000`) claims more and squeezes its
/// neighbours, shifting the row. The exposure chips need the stronger guarantee —
/// the photographer taps them by position, so a column must never move — so they
/// divide the available width arithmetically instead and let each chip lay itself
/// out inside its share.
struct EqualWidthRow: Layout {
    /// The gutter between columns.
    var spacing: CGFloat

    /// The width of one column when `count` of them share `totalWidth` with
    /// `spacing` between each pair. Pure, so the division is tested without a view.
    static func columnWidth(totalWidth: CGFloat, spacing: CGFloat, count: Int) -> CGFloat {
        guard count > 0 else { return 0 }
        let gutters = spacing * CGFloat(count - 1)
        return max(0, (totalWidth - gutters) / CGFloat(count))
    }

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout Void
    ) -> CGSize {
        guard !subviews.isEmpty else { return .zero }
        let column = columnWidth(for: proposal, subviews: subviews)
        let height = rowHeight(column: column, proposal: proposal, subviews: subviews)
        let gutters = spacing * CGFloat(subviews.count - 1)
        return CGSize(width: column * CGFloat(subviews.count) + gutters, height: height)
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout Void
    ) {
        guard !subviews.isEmpty else { return }
        let column = Self.columnWidth(
            totalWidth: bounds.width, spacing: spacing, count: subviews.count
        )
        let size = ProposedViewSize(width: column, height: bounds.height)
        for (index, subview) in subviews.enumerated() {
            let x = bounds.minX + (column + spacing) * CGFloat(index)
            subview.place(
                at: CGPoint(x: x, y: bounds.minY),
                proposal: size
            )
        }
    }

    /// The column width to lay out at. With a width proposed, it's that width
    /// divided up; unproposed (the ideal-size query), every column takes the widest
    /// subview's ideal width so the row still reports uniform columns.
    private func columnWidth(for proposal: ProposedViewSize, subviews: Subviews) -> CGFloat {
        guard let width = proposal.width else {
            return subviews.reduce(0) { max($0, $1.sizeThatFits(.unspecified).width) }
        }
        return Self.columnWidth(totalWidth: width, spacing: spacing, count: subviews.count)
    }

    /// The row is as tall as its tallest subview *at the column width it will
    /// actually get* — measuring at any other width would let a chip wrap or scale
    /// differently than it finally renders.
    private func rowHeight(
        column: CGFloat,
        proposal: ProposedViewSize,
        subviews: Subviews
    ) -> CGFloat {
        subviews.reduce(0) { height, subview in
            max(height, subview.sizeThatFits(ProposedViewSize(width: column, height: proposal.height)).height)
        }
    }
}
