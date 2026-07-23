import Testing
@testable import Lightmeter

/// The row's one piece of real logic: dividing the available width into columns of
/// exactly equal size. This is what an `HStack` can't promise — it hands each
/// flexible child an equal share only while every child's minimum fits — and it's
/// what keeps the exposure chips from shifting under the photographer's thumb.
struct EqualWidthRowTests {
    /// Three columns and two gutters exactly fill the row.
    @Test func columnsAndGuttersFillTheRow() {
        let width = EqualWidthRow.columnWidth(totalWidth: 320, spacing: 10, count: 3)
        #expect(width == 100)
        #expect(width * 3 + 10 * 2 == 320)
    }

    /// Every column is the same width by construction — there is no per-column
    /// content input at all, so no chip's label can claim more than its share.
    @Test func everyColumnIsTheSameWidth() {
        let widths = (0..<3).map { _ in
            EqualWidthRow.columnWidth(totalWidth: 353, spacing: 10, count: 3)
        }
        #expect(Set(widths).count == 1)
    }

    /// A single column takes the whole row: no gutters to subtract.
    @Test func oneColumnTakesTheWholeRow() {
        #expect(EqualWidthRow.columnWidth(totalWidth: 200, spacing: 10, count: 1) == 200)
    }

    /// Squeezed narrower than its own gutters, the row clamps to zero-width columns
    /// rather than proposing a negative width, which SwiftUI would reject.
    @Test func columnsNeverGoNegative() {
        #expect(EqualWidthRow.columnWidth(totalWidth: 10, spacing: 10, count: 3) == 0)
    }

    /// An empty row has nothing to divide.
    @Test func noColumnsIsZeroWide() {
        #expect(EqualWidthRow.columnWidth(totalWidth: 320, spacing: 10, count: 0) == 0)
    }
}
