import Foundation
import Testing

import SalusDatabase

@testable import SalusSmoking

@Suite("SmokingRepositoryImpl", .timeLimit(.minutes(1)))
struct SmokingRepositoryTests {
    private let env: SmokingTestEnv

    init() throws {
        env = try SmokingTestEnv()
    }

    private func makeRepository() -> SmokingRepositoryImpl {
        SmokingRepositoryImpl(
            dao: env.dao,
            store: DaoSmokingStore(dao: env.dao, listeners: env.module.changeListeners),
            clock: env.clock,
            idGenerator: env.ids
        )
    }

    @Test("a quit plan with no active attempt gets one at the plan's creation instant, once")
    func repairOpensAnAttempt() async throws {
        let createdAt = ms("2026-03-02T09:15")
        try await env.dao.upsertPlan(SmokingPlanRecordFixture.plan(mode: "QUIT", createdAtMs: createdAt))

        let first = try await env.input()
        let second = try await env.input()

        let attempt = try #require(first.attempts.first)
        #expect(first.attempts.count == 1)
        #expect(attempt.startedAtMs == createdAt)
        #expect(attempt.endedAtMs == nil)
        #expect(attempt.tzId == "Europe/Istanbul")
        #expect(second.attempts == first.attempts)
        // The repair is a change the reminders must hear about.
        #expect(env.notifications.value == 1)
    }

    @Test("the repair also re-derives the attempt of entries logged while the plan had none")
    func repairReattachesEntries() async throws {
        let createdAt = ms("2026-03-02T09:15")
        try await env.dao.upsertPlan(SmokingPlanRecordFixture.plan(mode: "QUIT", createdAtMs: createdAt))
        try await env.dao.insertEvent(
            SmokingEventRecordFixture.slip(id: "early", atMs: ms("2026-03-04T10:00"), attemptId: nil)
        )

        let input = try await env.input()

        #expect(input.events.first?.attemptId == input.attempts.first?.id)
    }

    @Test("the repair is idempotent across repository instances, as after a process restart")
    func repairIsIdempotent() async throws {
        try await env.dao.upsertPlan(
            SmokingPlanRecordFixture.plan(mode: "QUIT", createdAtMs: ms("2026-03-02T09:15"))
        )
        _ = try await env.input()

        let restarted = makeRepository()
        _ = await restarted.snapshotNow()
        var attempts = 0
        for await input in restarted.observeInput() {
            attempts = input.attempts.count
            break
        }

        #expect(attempts == 1)
        #expect(env.notifications.value == 1)
    }

    @Test("the repair leaves a reduce plan and a quit plan that has its attempt alone")
    func repairLeavesHealthyPlansAlone() async throws {
        try await env.dao.upsertPlan(
            SmokingPlanRecordFixture.plan(mode: "REDUCE", createdAtMs: ms("2026-03-02T09:15"))
        )
        #expect(try await env.input().attempts.isEmpty)
        #expect(env.notifications.value == 0)

        try await env.module.resetSmoking()
        try await env.quitSetUp()
        let before = try await env.input()
        let notified = env.notifications.value

        var after: SmokingInput?
        for await input in makeRepository().observeInput() {
            after = input
            break
        }

        #expect(after == before)
        #expect(env.notifications.value == notified)
    }

    @Test("an empty store is not set up")
    func emptyIsNotSetUp() async {
        #expect(await env.repository.snapshotNow() == .notSetUp)
    }

    @Test("the snapshot is the calculator's figures at the clock's now in its zone")
    func snapshotAtTheClocksNow() async throws {
        try await env.quitSetUp("2026-03-01T08:00")

        guard case let .quit(snapshot) = await env.repository.snapshotNow() else {
            Issue.record("expected a QUIT snapshot")
            return
        }

        #expect(snapshot.attemptElapsedMs == 9 * 86_400_000 + 4 * 3_600_000)
        #expect(try await snapshot.attemptId == (env.input().attempts.first?.id))
    }

    @Test("a write re-emits the snapshot")
    func writeReemitsTheSnapshot() async throws {
        try await env.quitSetUp("2026-03-10T08:00")
        var iterator = env.repository.observeSnapshot().makeAsyncIterator()

        let first = try #require(await quit(from: &iterator) { _ in true })
        #expect(first.attemptElapsedMs == 4 * 3_600_000)
        #expect(first.slipCount == 0)

        try await env.module.logSmoked(units: 1, atMs: ms("2026-03-10T11:00"))
        let afterWrite = try #require(await quit(from: &iterator) { $0.slipCount == 1 })
        #expect(afterWrite.slipCount == 1)
    }

    @Test("the minute tick recomputes the figures against the clock's new now")
    func minuteTickMovesTheFigures() async throws {
        // 12:00:59 - the first tick falls a second after subscribing, long before a full minute.
        let ticking = try SmokingTestEnv(nowLocal: "2026-03-10T12:00")
        ticking.clock.advanceTo(Date(epochMilliseconds: ms("2026-03-10T12:00") + 59000))
        try await ticking.quitSetUp("2026-03-10T08:00")
        var iterator = ticking.repository.observeSnapshot().makeAsyncIterator()
        let first = try #require(await quit(from: &iterator) { _ in true })

        ticking.clock.advanceTo(Date(epochMilliseconds: ms("2026-03-10T12:01") + 500))
        let afterTick = try #require(await quit(from: &iterator) { $0.attemptElapsedMs > first.attemptElapsedMs })

        #expect(afterTick.attemptElapsedMs == first.attemptElapsedMs + 1500)
    }

    @Test("switching modes never shows a quit plan without its attempt to an observer")
    func observerNeverSeesAMixedState() async throws {
        try await env.reduceSetUp()
        var iterator = env.repository.observeInput().makeAsyncIterator()

        func awaitConsistent(_ accept: (SmokingInput) -> Bool) async throws {
            while let input = await iterator.next() {
                // The state the UI routes on: QUIT must always come with an active attempt.
                if let plan = input.plan, plan.mode == .quit {
                    try #require(input.attempts.contains { $0.endedAtMs == nil }, "QUIT plan without an active attempt")
                }
                if accept(input) {
                    return
                }
            }
            Issue.record("the stream ended")
        }

        try await awaitConsistent { _ in true }
        for _ in 0 ..< 15 {
            try await env.module.switchMode(to: .quit)
            try await awaitConsistent { $0.plan?.mode == .quit }
            try await env.module.switchMode(to: .reduce, dailyLimit: 5)
            try await awaitConsistent { $0.plan?.mode == .reduce }
        }
    }

    @Test("an unchanged store emits once, however many table observers fire at subscription")
    func unchangedStoreEmitsOnce() async throws {
        try await env.quitSetUp()
        let counter = NotificationCounter()
        let stream = env.repository.observeInput()
        let collector = Task {
            for await _ in stream {
                counter.smokingDataChanged()
            }
        }

        try await Task.sleep(for: .milliseconds(400))
        collector.cancel()

        #expect(counter.value == 1)
    }

    /// The next QUIT snapshot that `accept`s. The minute tick may re-emit an older state first.
    private func quit(
        from iterator: inout AsyncStream<SmokingSnapshot>.AsyncIterator,
        where accept: (QuitSnapshot) -> Bool
    ) async -> QuitSnapshot? {
        while let snapshot = await iterator.next() {
            if case let .quit(value) = snapshot, accept(value) {
                return value
            }
        }
        return nil
    }
}
