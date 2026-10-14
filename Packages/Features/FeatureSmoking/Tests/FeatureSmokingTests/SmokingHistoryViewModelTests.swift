// Ported from `feature/smoking/src/test/kotlin/com/alicansekban/salus/feature/smoking/ui/history/
// SmokingHistoryViewModelTest.kt`.
//
// The ViewModel is exercised over the real calculator and the real `EditEvent` / `DeleteEvent`;
// only the store is fake. `advanceUntilIdle()` becomes `waitUntil`, and the Turbine
// `effects.test { awaitItem() }` becomes `consumeEffects()` after the write has landed.

import Foundation
import SalusSmoking
import Testing

@testable import FeatureSmoking

@MainActor
@Suite("SmokingHistoryViewModel", .timeLimit(.minutes(1)))
struct SmokingHistoryViewModelTests {
    // MARK: State

    @Test("nothing is on show before the first rows")
    func nothingBeforeTheFirstRows() {
        let state = HistoryHarness().viewModel().state

        #expect(!state.loaded)
        // An empty log is only claimed once the rows have loaded.
        #expect(!state.isEmpty)
        #expect(!state.showHowTo)
    }

    @Test("a plan with neither entries nor attempts is the empty state")
    func planWithNothingIsEmpty() async {
        let harness = HistoryHarness(
            SmokingInput(
                plan: HistoryHarness().plan(.reduce),
                prices: HistoryHarness.prices,
                attempts: [],
                events: [],
                goal: nil
            )
        )

        let state = await harness.loadedViewModel().state

        #expect(state.loaded)
        #expect(state.isEmpty)
        #expect(state.showHowTo)
        #expect(state.days.isEmpty)
    }

    @Test("a quit plan with a running attempt but no entries keeps its journey and attempt")
    func runningAttemptKeepsItsScreen() async {
        let state = await HistoryHarness().loadedViewModel().state

        // The first visit still shows the journey and the running attempt.
        #expect(!state.isEmpty)
        #expect(state.days.isEmpty)
        #expect(state.attempts.count == 1)
        #expect(state.attempts.first?.isActive == true)
        // The explainer moves into the log section.
        #expect(state.showHowTo)
    }

    @Test("the explainer goes once there is an entry to show")
    func explainerGoesWithTheFirstEntry() async {
        let harness = HistoryHarness()
        let state = await HistoryHarness(events: [harness.craving("c", at: "2026-03-10T10:00")])
            .loadedViewModel().state

        #expect(!state.isEmpty)
        #expect(!state.showHowTo)
    }

    @Test("entries are grouped by their stored day, newest day and newest entry first")
    func entriesAreGroupedNewestFirst() async {
        let fx = HistoryHarness()
        let state = await HistoryHarness(
            events: [
                fx.smoked("a", at: "2026-03-08T09:15"),
                fx.craving("b", at: "2026-03-10T14:20"),
                fx.craving("c", at: "2026-03-08T21:40"),
                fx.smoked("d", at: "2026-03-10T08:00", units: 2)
            ]
        ).loadedViewModel().state

        #expect(state.days.map(\.epochDay) == [
            fx.dayOf(fx.ms("2026-03-10T00:00")),
            fx.dayOf(fx.ms("2026-03-08T00:00"))
        ])
        #expect(state.days[0].rows.map(\.id) == ["b", "d"])
        #expect(state.days[1].rows.map(\.id) == ["c", "a"])
        // Today's group is told apart for the "Bugün" label.
        #expect(state.todayEpochDay == fx.dayOf(fx.nowMs))
    }

    @Test("a row carries what the log shows and nothing else")
    func rowCarriesWhatTheLogShows() async throws {
        let fx = HistoryHarness()
        let state = await HistoryHarness(
            events: [fx.smoked("a", at: "2026-03-10T09:15", units: 2, trigger: .stress, intensity: 4)]
        ).loadedViewModel().state

        let row = try #require(state.days.first?.rows.first)
        #expect(row.type == .smoked)
        #expect(row.units == 2)
        #expect(row.trigger == .stress)
        #expect(row.intensity == 4)
        #expect(row.atMs == fx.ms("2026-03-10T09:15"))
        #expect(row.tzId == fx.zone.identifier)
        #expect(!row.isMarker)
    }

    @Test("a zero-unit smoked entry is the none-today marker")
    func zeroUnitEntryIsTheMarker() async {
        let fx = HistoryHarness()
        let state = await HistoryHarness(events: [fx.smoked("m", at: "2026-03-10T09:00", units: 0)])
            .loadedViewModel().state

        #expect(state.days.first?.rows.first?.isMarker == true)
    }

    @Test("the journey counts whole days from the earliest start")
    func journeyCountsFromTheEarliestStart() async {
        let fx = HistoryHarness()
        let attempts = [
            QuitAttempt(
                id: "attempt-0",
                startedAtMs: fx.nowMs - 130 * dayMs - 3 * hourMs,
                tzId: fx.zone.identifier,
                endedAtMs: fx.nowMs - 50 * dayMs,
                endReason: .restarted
            ),
            QuitAttempt(
                id: "attempt-1",
                startedAtMs: fx.nowMs - 42 * dayMs,
                tzId: fx.zone.identifier,
                endedAtMs: nil,
                endReason: nil
            )
        ]

        let state = await HistoryHarness(attempts: attempts).loadedViewModel().state

        // An attempt that began before the plan was written starts the journey.
        #expect(state.journeyDays == 130)
    }

    @Test("a plan older than every attempt starts the journey at the plan")
    func planStartsTheJourneyWhenItIsOlder() async {
        // The plan was written 100 days ago; the only attempt began 42 days ago.
        let state = await HistoryHarness().loadedViewModel().state

        #expect(state.journeyDays == 100)
    }

    // MARK: Attempts

    @Test("a quit snapshot's attempts become cards in order with the longest marked")
    func quitAttemptsBecomeCards() async {
        let fx = HistoryHarness()
        let attempts = [
            QuitAttempt(
                id: "attempt-0",
                startedAtMs: fx.nowMs - 80 * dayMs,
                tzId: fx.zone.identifier,
                endedAtMs: fx.nowMs - 62 * dayMs,
                endReason: .restarted
            ),
            QuitAttempt(
                id: "attempt-1",
                startedAtMs: fx.nowMs - 42 * dayMs,
                tzId: fx.zone.identifier,
                endedAtMs: nil,
                endReason: nil
            )
        ]

        let cards = await HistoryHarness(
            events: [fx.smoked("s1", at: "2026-02-20T10:00", attempt: "attempt-1")],
            attempts: attempts
        ).loadedViewModel().state.attempts

        #expect(cards.map(\.ordinal) == [1, 2])
        #expect(cards.map(\.isActive) == [false, true])
        // The active attempt (42 d) is longer than the closed one (18 d).
        #expect(cards.map(\.isLongest) == [false, true])
        #expect(cards.map(\.slipCount) == [0, 1])
        #expect(cards[1].durationMs == 42 * dayMs)
        // A quit card carries the money the snapshot computed.
        #expect(cards[1].savedMinor != nil)
    }

    @Test("in REDUCE the closed attempts still show, from the stored rows, without money")
    func reduceShowsClosedAttemptsWithoutMoney() async throws {
        let fx = HistoryHarness()
        let input = SmokingInput(
            plan: fx.plan(.reduce),
            prices: HistoryHarness.prices,
            attempts: [
                QuitAttempt(
                    id: "attempt-0",
                    startedAtMs: fx.nowMs - 100 * dayMs,
                    tzId: fx.zone.identifier,
                    endedAtMs: fx.nowMs - 60 * dayMs,
                    endReason: .switchedToReduce
                )
            ],
            events: [fx.smoked("s1", at: "2026-01-20T10:00", attempt: "attempt-0")],
            goal: nil
        )

        let card = try #require(await HistoryHarness(input).loadedViewModel().state.attempts.first)

        #expect(card.ordinal == 1)
        #expect(!card.isActive)
        #expect(card.durationMs == 40 * dayMs)
        #expect(card.slipCount == 1)
        #expect(card.isLongest)
        // A closed REDUCE-era attempt has no snapshot money to show.
        #expect(card.savedMinor == nil)
        #expect(card.cravingsBeaten == nil)
    }

    @Test("in REDUCE the earliest of two equally long closed attempts is the longest")
    func reduceTieGoesToTheEarliestAttempt() async {
        let fx = HistoryHarness()
        let input = SmokingInput(
            plan: fx.plan(.reduce),
            prices: HistoryHarness.prices,
            attempts: [
                QuitAttempt(
                    id: "attempt-b",
                    startedAtMs: fx.nowMs - 50 * dayMs,
                    tzId: fx.zone.identifier,
                    endedAtMs: fx.nowMs - 40 * dayMs,
                    endReason: .restarted
                ),
                QuitAttempt(
                    id: "attempt-a",
                    startedAtMs: fx.nowMs - 100 * dayMs,
                    tzId: fx.zone.identifier,
                    endedAtMs: fx.nowMs - 90 * dayMs,
                    endReason: .restarted
                )
            ],
            events: [],
            goal: nil
        )

        let cards = await HistoryHarness(input).loadedViewModel().state.attempts

        #expect(cards.map(\.id) == ["attempt-a", "attempt-b"])
        #expect(cards.map(\.isLongest) == [true, false])
    }
}
