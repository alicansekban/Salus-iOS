// Ported from `feature/smoking/src/test/kotlin/com/alicansekban/salus/feature/smoking/ui/main/
// ReduceViewTest.kt` (branch `feature/m17-smoking-cessation`): what the REDUCE body shows is
// decided from the snapshot alone, so the rules are plain logic and no view is built.

import SalusSmoking
import Testing

@testable import FeatureSmoking

@Suite("ReduceView")
struct ReduceViewTests {
    private func plan(product: ProductType = .cigarette, baseline: Int64 = 20) -> SmokingPlan {
        SmokingPlan(
            id: "plan",
            mode: .reduce,
            productType: product,
            baselineUnitsPerDay: baseline,
            dailyLimit: 10,
            currencyCode: "TRY",
            reason: nil,
            notificationsEnabled: true,
            eveningReminderEnabled: false,
            createdAtMs: 0,
            tzId: "Europe/Istanbul"
        )
    }

    private func reduce(
        today: Int64,
        hasEntry: Bool? = nil,
        limit: Int64 = 10,
        product: ProductType = .cigarette,
        week: [Int64?]? = nil,
        weekReduction: Int64 = 23,
        weekSaved: Int64 = 16100
    ) -> ReduceSnapshot {
        let days = week ?? [8, 7, 6, 7, 6, 5, today]
        return ReduceSnapshot(
            plan: plan(product: product),
            todayEpochDay: 100,
            todayUnits: today,
            todayHasEntry: hasEntry ?? (today > 0),
            dailyLimit: limit,
            last7Days: days.enumerated().map { DayUnits(epochDay: 94 + Int64($0.offset), units: $0.element) },
            weekReductionUnits: weekReduction,
            weekSavedMinor: weekSaved,
            savedSinceSetupMinor: weekSaved,
            cravingsBeatenAllTime: 0,
            stagesPreview: [],
            goal: nil
        )
    }

    // MARK: Tone and ring

    @Test("a day with nothing logged is the empty tone with an empty ring")
    func emptyDay() {
        let view = reduce(today: 0, hasEntry: false, week: Array(repeating: nil, count: 7)).toView()

        #expect(view.tone == .empty)
        #expect(view.progressPermille == 0)
        #expect(view.overflowPermille == 0)
        #expect(view.overBy == 0)
        #expect(view.limit == 10)
    }

    @Test("under the limit the ring fills to the share and says what is left")
    func underTheLimit() {
        let view = reduce(today: 6).toView()

        #expect(view.tone == .under)
        #expect(view.progressPermille == 600)
        #expect(view.overflowPermille == 0)
        #expect(view.remaining == 4)
    }

    @Test("at the limit the ring is full and nothing overflows")
    func atTheLimit() {
        let view = reduce(today: 10).toView()

        #expect(view.tone == .at)
        #expect(view.progressPermille == 1000)
        #expect(view.overflowPermille == 0)
        #expect(view.overBy == 0)
    }

    @Test("over the limit the ring stays full and the excess goes to the overflow arc")
    func overTheLimit() {
        let view = reduce(today: 12).toView()

        #expect(view.tone == .over)
        #expect(view.progressPermille == 1000)
        #expect(view.overflowPermille == 200)
        #expect(view.overBy == 2)
    }

    @Test("the overflow arc is one lap at most, while the chip still says the real excess")
    func overflowIsOneLapAtMost() {
        let view = reduce(today: 35).toView()

        #expect(view.overflowPermille == 1000)
        #expect(view.overBy == 25)
    }

    @Test("a day logged as none is the empty tone, not a missing day")
    func noneTodayIsEmptyTone() {
        let view = reduce(today: 0, hasEntry: true).toView()

        #expect(view.tone == .empty)
        #expect(!view.showNoneToday)
    }

    @Test("a limit of zero reads as one, so the ring never divides by zero")
    func zeroLimitReadsAsOne() {
        let view = reduce(today: 1, limit: 0).toView()

        #expect(view.limit == 1)
        #expect(view.tone == .at)
        #expect(view.progressPermille == 1000)
    }

    // MARK: None today

    @Test("none today is offered while the day has no entry")
    func noneTodayOffered() {
        #expect(reduce(today: 0, hasEntry: false).toView().showNoneToday)
    }

    @Test("none today is gone once the day has an entry")
    func noneTodayGone() {
        #expect(!reduce(today: 1).toView().showNoneToday)
    }

    // MARK: Over-limit comparison

    @Test("over the limit the copy compares with the old average while it is still higher")
    func belowBaseline() {
        #expect(reduce(today: 12).toView().belowBaseline == 8)
    }

    @Test("no comparison when the day is not over the limit")
    func noComparisonUnderTheLimit() {
        #expect(reduce(today: 6).toView().belowBaseline == nil)
    }

    @Test("no comparison when the day is over the old average too")
    func noComparisonOverTheAverage() {
        #expect(reduce(today: 25).toView().belowBaseline == nil)
    }

    // MARK: Week bars

    @Test("a day without data is an empty slot and is never read as zero")
    func missingDayIsNotZero() {
        let view = reduce(today: 3, week: [nil, nil, nil, 8, 7, 6, 3]).toView()

        #expect(view.bars.map(\.units) == [nil, nil, nil, 8, 7, 6, 3])
        #expect(view.bars.map(\.epochDay) == [94, 95, 96, 97, 98, 99, 100])
    }

    // MARK: Vape (contract 8.12)

    @Test("the baseline marker carries the plan's old average")
    func baselineMarker() {
        #expect(reduce(today: 3).toView().baseline == 20)
    }

    @Test("a vape shows money only, with no unit reduction and no baseline marker")
    func vapeIsMoneyOnly() {
        let view = reduce(today: 3, product: .vape).toView()

        #expect(view.baseline == nil)
        #expect(view.weekReductionUnits == nil)
        #expect(view.weekSavedMinor == 16100)
        #expect(view.belowBaseline == nil)
    }

    @Test("every other product shows the unit reduction", arguments: ProductType.allCases.filter { $0 != .vape })
    func otherProductsShowReduction(product: ProductType) {
        #expect(reduce(today: 3, product: product).toView().weekReductionUnits == 23)
    }
}
