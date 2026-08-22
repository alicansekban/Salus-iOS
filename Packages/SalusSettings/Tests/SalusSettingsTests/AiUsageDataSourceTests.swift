import Foundation
import Testing

@testable import SalusSettings

// Ported case for case from Android
// `core/datastore/src/test/kotlin/.../AiUsageDataSourceTest.kt`.
//
// The day-reset rule is the part that can silently hand out free calls forever, so it is covered
// twice: as a pure reduction (every branch, no IO) and through a real store to prove the
// reduction is actually the one `recordCall` applies (`AiUsageDataSourceTest.kt:21-25`).

/// 2026-08-20 — an arbitrary but realistic epoch day (`AiUsageDataSourceTest.kt:170`).
private let today = 20685

/// One `recordedOn` row: the stored counter, the day the call is made on, what must come out.
struct RecordedOnRow: Sendable, CustomStringConvertible {
    let name: String
    let stored: AiCallCount
    let todayEpochDay: Int
    let expected: AiCallCount

    var description: String { name }
}

/// Every branch of `AiCallCount.recordedOn` (`AiUsageDataSource.kt:60-65`) in one table.
let recordedOnRows: [RecordedOnRow] = [
    RecordedOnRow(
        name: "the counter's own day increments it",
        stored: AiCallCount(epochDay: today, count: 4),
        todayEpochDay: today,
        expected: AiCallCount(epochDay: today, count: 5)
    ),
    RecordedOnRow(
        name: "an earlier day restarts at one on today",
        stored: AiCallCount(epochDay: today - 1, count: 9),
        todayEpochDay: today,
        expected: AiCallCount(epochDay: today, count: 1)
    ),
    RecordedOnRow(
        name: "a later day restarts at one on today",
        stored: AiCallCount(epochDay: today + 1, count: 3),
        todayEpochDay: today,
        expected: AiCallCount(epochDay: today, count: 1)
    ),
    RecordedOnRow(
        name: "the never-called counter restarts at one on today",
        stored: AiCallCount(epochDay: 0, count: 0),
        todayEpochDay: today,
        expected: AiCallCount(epochDay: today, count: 1)
    ),
    RecordedOnRow(
        name: "the never-called counter increments on epoch day zero itself",
        stored: AiCallCount(epochDay: 0, count: 0),
        todayEpochDay: 0,
        expected: AiCallCount(epochDay: 0, count: 1)
    )
]

@Suite("AiCallCount.recordedOn (pure reduction)")
struct AiCallCountTests {
    @Test("the day branch decides increment or restart", arguments: recordedOnRows)
    func recordedOnBranches(_ row: RecordedOnRow) {
        #expect(row.stored.recordedOn(todayEpochDay: row.todayEpochDay) == row.expected, "\(row.name)")
    }

    @Test("same day increments the counter")
    func sameDayIncrementsTheCounter() {
        let start = AiCallCount(epochDay: today, count: 0)

        let first = start.recordedOn(todayEpochDay: today)
        let second = first.recordedOn(todayEpochDay: today)
        let third = second.recordedOn(todayEpochDay: today)

        #expect(first == AiCallCount(epochDay: today, count: 1))
        #expect(second == AiCallCount(epochDay: today, count: 2))
        #expect(third == AiCallCount(epochDay: today, count: 3))
    }

    @Test("a new day restarts the counter at one and moves the day")
    func aNewDayRestartsTheCounterAtOneAndMovesTheDay() {
        let yesterdayAtNine = AiCallCount(epochDay: today - 1, count: 9)

        #expect(yesterdayAtNine.recordedOn(todayEpochDay: today) == AiCallCount(epochDay: today, count: 1))
    }

    @Test("a clock moved backwards also restarts the counter")
    func aClockMovedBackwardsAlsoRestartsTheCounter() {
        let tomorrowAtThree = AiCallCount(epochDay: today + 1, count: 3)

        #expect(tomorrowAtThree.recordedOn(todayEpochDay: today) == AiCallCount(epochDay: today, count: 1))
    }

    @Test("the never-called state counts its first call as one")
    func theNeverCalledStateCountsItsFirstCallAsOne() {
        let never = AiCallCount(
            epochDay: AiUsage.default.callsEpochDay,
            count: AiUsage.default.callsToday
        )

        #expect(never.recordedOn(todayEpochDay: today) == AiCallCount(epochDay: today, count: 1))
    }
}

@Suite("AiUsage.callsOn (read-side day guard)")
struct AiUsageCallsOnTests {
    @Test("callsOn returns the count when it belongs to today")
    func callsOnReturnsTheCountWhenItBelongsToToday() {
        let usage = AiUsage(freeSummaryUsed: false, callsEpochDay: today, callsToday: 4)

        #expect(usage.callsOn(todayEpochDay: today) == 4)
    }

    @Test("callsOn ignores a count left over from an earlier day")
    func callsOnIgnoresACountLeftOverFromAnEarlierDay() {
        let yesterdaysQuotaSpent = AiUsage(
            freeSummaryUsed: true,
            callsEpochDay: today - 1,
            callsToday: 99
        )

        // Nothing has been written since midnight, so the stored count is stale, not binding.
        #expect(yesterdaysQuotaSpent.callsOn(todayEpochDay: today) == 0)
    }

    @Test("callsOn ignores a count stamped with a later day")
    func callsOnIgnoresACountStampedWithALaterDay() {
        let fromAForwardClock = AiUsage(
            freeSummaryUsed: false,
            callsEpochDay: today + 1,
            callsToday: 7
        )

        #expect(fromAForwardClock.callsOn(todayEpochDay: today) == 0)
    }

    @Test("callsOn reports nothing spent for the default usage on any day")
    func callsOnReportsNothingSpentForTheDefaultUsageOnAnyDay() {
        #expect(AiUsage.default.callsOn(todayEpochDay: today) == 0)
        #expect(AiUsage.default.callsOn(todayEpochDay: AiUsage.default.callsEpochDay) == 0)
        #expect(AiUsage.default.callsOn(todayEpochDay: today + 1) == 0)
    }
}

@Suite("AiUsageDataSource (stream + writes)")
struct AiUsageDataSourceTests {
    private struct Fixture {
        let env: TestUserDefaults
        let source: AiUsageDataSource
    }

    private func makeFixture() throws -> Fixture {
        let env = try TestUserDefaults()
        return Fixture(env: env, source: AiUsageDataSource(defaults: env.defaults))
    }

    /// `AiUsageDataSourceTest.kt:166` — `dataSource.usage.first()`.
    private func usage(_ fixture: Fixture) async throws -> AiUsage {
        try #require(await fixture.source.usage.firstValue())
    }

    @Test("an untouched store reports the default usage")
    func anUntouchedStoreReportsTheDefaultUsage() async throws {
        let fixture = try makeFixture()

        let read = try await usage(fixture)
        #expect(read == AiUsage(freeSummaryUsed: false, callsEpochDay: 0, callsToday: 0))
        #expect(read == AiUsage.default)
    }

    @Test("recordCall increments within a day and resets across days")
    func recordCallIncrementsWithinADayAndResetsAcrossDays() async throws {
        let fixture = try makeFixture()

        fixture.source.recordCall(todayEpochDay: today)
        #expect(try await usage(fixture).callsToday == 1)

        fixture.source.recordCall(todayEpochDay: today)
        fixture.source.recordCall(todayEpochDay: today)
        #expect(
            try await usage(fixture)
                == AiUsage(freeSummaryUsed: false, callsEpochDay: today, callsToday: 3)
        )

        fixture.source.recordCall(todayEpochDay: today + 1)
        #expect(
            try await usage(fixture)
                == AiUsage(freeSummaryUsed: false, callsEpochDay: today + 1, callsToday: 1)
        )
    }

    @Test("markFreeSummaryUsed is idempotent and leaves the call counters alone")
    func markFreeSummaryUsedIsIdempotentAndLeavesTheCallCountersAlone() async throws {
        let fixture = try makeFixture()
        fixture.source.recordCall(todayEpochDay: today)

        fixture.source.markFreeSummaryUsed()
        #expect(try await usage(fixture).freeSummaryUsed)

        fixture.source.markFreeSummaryUsed()
        #expect(
            try await usage(fixture)
                == AiUsage(freeSummaryUsed: true, callsEpochDay: today, callsToday: 1)
        )
    }

    @Test("recording a call does not spend the free summary")
    func recordingACallDoesNotSpendTheFreeSummary() async throws {
        let fixture = try makeFixture()

        fixture.source.recordCall(todayEpochDay: today)

        #expect(try await usage(fixture).freeSummaryUsed == false)
    }

    @Test("the usage stream emits the current value first, then every change")
    func theUsageStreamEmitsCurrentThenChanges() async throws {
        let fixture = try makeFixture()
        // See the note on `StreamRecorder`: an iterator would let a spurious duplicate be
        // collapsed by `.bufferingNewest(1)` and the idempotence claim below would be vacuous.
        let recorder = StreamRecorder(fixture.source.usage)

        await recorder.wait(forAtLeast: 1)
        fixture.source.recordCall(todayEpochDay: today)
        await recorder.wait(forAtLeast: 2)
        fixture.source.markFreeSummaryUsed()
        await recorder.wait(forAtLeast: 3)

        // Writing true over true is a no-op for the value, so the stream stays quiet.
        fixture.source.markFreeSummaryUsed()
        await Task.yield()
        fixture.source.recordCall(todayEpochDay: today)
        await recorder.wait(forAtLeast: 4)

        #expect(recorder.recorded == [
            AiUsage.default,
            AiUsage(freeSummaryUsed: false, callsEpochDay: today, callsToday: 1),
            AiUsage(freeSummaryUsed: true, callsEpochDay: today, callsToday: 1),
            AiUsage(freeSummaryUsed: true, callsEpochDay: today, callsToday: 2)
        ])
    }

    @Test("a day rollover is published as one value, never as yesterday's count under today")
    func aDayRolloverIsNeverPublishedTorn() async throws {
        let fixture = try makeFixture()
        for _ in 0 ..< 47 {
            fixture.source.recordCall(todayEpochDay: today - 1)
        }

        let recorder = StreamRecorder(fixture.source.usage)
        await recorder.wait(forAtLeast: 1)
        #expect(recorder.recorded.last?.callsToday == 47)

        fixture.source.recordCall(todayEpochDay: today)
        await recorder.wait(forAtLeast: 2)

        // `recordCall` writes two keys, and `UserDefaults` posts `didChangeNotification`
        // synchronously from inside `set` — so between the two writes the observer would see
        // `(epochDay: today, callsToday: 47)`: a fresh day already carrying yesterday's spent
        // quota, which `callsOn(today)` reports as an exhausted allowance. Kotlin's single
        // `edit` block (`AiUsageDataSource.kt:106-114`) makes that state unobservable; the
        // batching in `DefaultsValueStream` is what makes it unobservable here.
        let torn = recorder.recorded.filter { $0.callsEpochDay == today && $0.callsToday != 1 }
        #expect(torn.isEmpty, "torn values: \(torn)")

        #expect(recorder.recorded == [
            AiUsage(freeSummaryUsed: false, callsEpochDay: today - 1, callsToday: 47),
            AiUsage(freeSummaryUsed: false, callsEpochDay: today, callsToday: 1)
        ])
    }

    @Test("the AI counters are stored under the three Android keys")
    func countersUseTheAndroidKeys() throws {
        let fixture = try makeFixture()

        fixture.source.recordCall(todayEpochDay: today)
        fixture.source.markFreeSummaryUsed()

        // `AiUsageDataSource.kt:118-120`. Asserted through the raw suite so a renamed key cannot
        // hide behind a reader that was renamed with it.
        #expect(fixture.env.defaults.bool(forKey: SettingsKeys.aiFreeSummaryUsed))
        #expect(fixture.env.defaults.integer(forKey: SettingsKeys.aiCallsEpochDay) == today)
        #expect(fixture.env.defaults.integer(forKey: SettingsKeys.aiCallsCount) == 1)
    }
}
