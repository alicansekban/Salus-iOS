// Which dot is the active one, pinned without rendering the row.
//
// Kotlin compares `page == currentPage` inside `repeat(pageCount)` (`SalusPagerDots.kt:44-45`), so
// an out-of-range page simply stretches no dot. The iOS port answers the same question as a number
// the row can index with, which means it has to say what an out-of-range index resolves to — a
// carousel that has scrolled past its last page still has to mark a page as current.

import Testing

@testable import SalusUI

@Suite("SalusPagerDots")
struct SalusPagerDotsTests {
    @Test("an in-range index is the active dot", arguments: [0, 1, 3])
    func inRangeIndexIsTheActiveDot(_ index: Int) {
        #expect(SalusPagerDots.clampedIndex(index: index, count: 4) == index)
    }

    @Test("an index past the last page clamps to it", arguments: [4, 9, .max])
    func indexPastTheLastPageClampsToIt(_ index: Int) {
        #expect(SalusPagerDots.clampedIndex(index: index, count: 4) == 3)
    }

    @Test("a negative index clamps to the first page", arguments: [-1, -7, .min])
    func negativeIndexClampsToTheFirstPage(_ index: Int) {
        #expect(SalusPagerDots.clampedIndex(index: index, count: 4) == 0)
    }

    /// No pages, no dots: the row draws nothing, and the index it would have used is zero rather
    /// than the `-1` a bare `count - 1` would hand a `ForEach`.
    @Test("an empty pager has no page to mark", arguments: [0, -2])
    func emptyPagerHasNoPageToMark(_ count: Int) {
        #expect(SalusPagerDots.clampedIndex(index: 2, count: count) == 0)
    }
}
