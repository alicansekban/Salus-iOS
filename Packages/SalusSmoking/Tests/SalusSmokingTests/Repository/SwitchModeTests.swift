import Testing

@testable import SalusSmoking

@Suite("SwitchMode", .timeLimit(.minutes(1)))
struct SwitchModeTests {
    private let env: SmokingTestEnv

    init() throws {
        env = try SmokingTestEnv()
    }

    @Test("quit to reduce closes the attempt with its reason, sets the limit and keeps every row")
    func quitToReduceKeepsData() async throws {
        try await env.quitSetUp()
        try await env.module.resolveSlip(units: 1, atMs: ms("2026-03-09T10:00"), restart: false)
        try await env.module.logCravingResisted(atMs: ms("2026-03-09T11:00"))
        let before = try await env.input()

        try await env.module.switchMode(to: .reduce, dailyLimit: 6)

        let after = try await env.input()
        let plan = try #require(after.plan)
        #expect(plan.mode == .reduce)
        #expect(plan.dailyLimit == 6)
        let attempt = try #require(after.attempts.first)
        #expect(after.attempts.count == 1)
        #expect(attempt.endedAtMs == ms("2026-03-10T12:00"))
        #expect(attempt.endReason == .switchedToReduce)
        #expect(after.events == before.events)
        #expect(after.prices == before.prices)
    }

    @Test("quit to reduce needs a daily limit and changes nothing without one")
    func quitToReduceNeedsALimit() async throws {
        try await env.quitSetUp()

        await #expect(throws: SmokingError.invalidInput) {
            try await env.module.switchMode(to: .reduce)
        }

        let input = try await env.input()
        #expect(input.plan?.mode == .quit)
        #expect(input.attempts.first?.endedAtMs == nil)
    }

    @Test("reduce to quit opens an attempt at the given past instant and keeps every row")
    func reduceToQuitKeepsData() async throws {
        try await env.reduceSetUp()
        try await env.module.logSmoked(units: 2, atMs: ms("2026-03-09T10:00"))
        let before = try await env.input()
        let quitAt = ms("2026-03-10T08:00")

        try await env.module.switchMode(to: .quit, quitAtMs: quitAt)

        let after = try await env.input()
        let plan = try #require(after.plan)
        #expect(plan.mode == .quit)
        #expect(plan.dailyLimit == nil)
        let attempt = try #require(after.attempts.first)
        #expect(after.attempts.count == 1)
        #expect(attempt.startedAtMs == quitAt)
        #expect(attempt.endedAtMs == nil)
        #expect(after.events == before.events)
    }

    @Test("reduce to quit defaults to now and rejects a future instant")
    func reduceToQuitDefaultsToNow() async throws {
        try await env.reduceSetUp()

        await #expect(throws: SmokingError.futureQuitDate) {
            try await env.module.switchMode(to: .quit, quitAtMs: ms("2026-03-10T12:00") + 1)
        }
        #expect(try await env.input().plan?.mode == .reduce)

        try await env.module.switchMode(to: .quit)
        #expect(try await env.input().attempts.first?.startedAtMs == ms("2026-03-10T12:00"))
    }

    @Test("a back-dated quit turns the reduce entries since then into slips of the new attempt")
    func backDatedQuitReattachesEntries() async throws {
        try await env.reduceSetUp()
        try await env.module.logSmoked(units: 1, atMs: ms("2026-03-09T10:00")) // before the quit instant
        try await env.module.logSmoked(units: 1, atMs: ms("2026-03-10T09:00")) // after it

        try await env.module.switchMode(to: .quit, quitAtMs: ms("2026-03-10T08:00"))

        let input = try await env.input()
        let attemptId = try #require(input.attempts.first?.id)
        #expect(input.events.map(\.attemptId) == [nil, attemptId])
    }

    @Test("switching to the mode it is already in, or with no plan, fails")
    func sameModeOrNoPlan() async throws {
        await #expect(throws: SmokingError.notSetUp) {
            try await env.module.switchMode(to: .quit)
        }

        try await env.quitSetUp()
        await #expect(throws: SmokingError.invalidInput) {
            try await env.module.switchMode(to: .quit)
        }
    }

    @Test("going back to quit before the previous attempt ended is invalid, the same instant is allowed")
    func attemptsNeverOverlap() async throws {
        try await env.quitSetUp()
        try await env.module.switchMode(to: .reduce, dailyLimit: 6) // closes the attempt at 12:00
        let before = try await env.input()

        await #expect(throws: SmokingError.invalidInput) {
            try await env.module.switchMode(to: .quit, quitAtMs: ms("2026-03-10T11:00"))
        }
        #expect(try await env.input() == before)

        try await env.module.switchMode(to: .quit, quitAtMs: ms("2026-03-10T12:00"))
        #expect(try await env.input().attempts.count == 2)
    }
}

@Suite("EditQuitDate", .timeLimit(.minutes(1)))
struct EditQuitDateTests {
    private let env: SmokingTestEnv

    init() throws {
        env = try SmokingTestEnv()
    }

    @Test("a later quit date detaches the slips that now fall before it")
    func laterDateDetaches() async throws {
        try await env.quitSetUp("2026-03-01T08:00")
        try await env.module.logSmoked(units: 1, atMs: ms("2026-03-03T10:00"))
        try await env.module.logSmoked(units: 1, atMs: ms("2026-03-08T10:00"))
        let attemptId = try #require(try await env.input().attempts.first?.id)

        try await env.module.editQuitDate(newStartMs: ms("2026-03-05T08:00"))

        let input = try await env.input()
        #expect(input.attempts.first?.startedAtMs == ms("2026-03-05T08:00"))
        #expect(input.events.map(\.attemptId) == [nil, attemptId])
        guard case let .quit(snapshot) = await env.repository.snapshotNow() else {
            Issue.record("expected a QUIT snapshot")
            return
        }
        #expect(snapshot.slipCount == 1)
    }

    @Test("an earlier quit date attaches the entries it now covers")
    func earlierDateAttaches() async throws {
        try await env.quitSetUp("2026-03-05T08:00")
        try await env.module.logSmoked(units: 1, atMs: ms("2026-03-03T10:00"))
        #expect(try await env.input().events.first?.attemptId == nil)

        try await env.module.editQuitDate(newStartMs: ms("2026-03-01T08:00"))

        let input = try await env.input()
        #expect(input.events.first?.attemptId == input.attempts.first?.id)
    }

    @Test("the event that restarted an attempt stays on the attempt it ended")
    func restartEventStaysOnTheClosedAttempt() async throws {
        try await env.quitSetUp("2026-03-01T08:00")
        try await env.module.resolveSlip(units: 1, atMs: ms("2026-03-05T10:00"), restart: true)

        try await env.module.editQuitDate(newStartMs: ms("2026-03-06T00:00"))

        let input = try await env.input()
        #expect(input.events.first?.attemptId == input.attempts.first?.id)
    }

    @Test("a future quit date is rejected and changes nothing")
    func futureDate() async throws {
        try await env.quitSetUp()
        let before = try await env.input()

        await #expect(throws: SmokingError.futureQuitDate) {
            try await env.module.editQuitDate(newStartMs: ms("2026-03-10T12:00") + 1)
        }

        #expect(try await env.input() == before)
    }

    @Test("it needs an active attempt")
    func needsAnActiveAttempt() async throws {
        await #expect(throws: SmokingError.notSetUp) {
            try await env.module.editQuitDate(newStartMs: ms("2026-03-01T08:00"))
        }

        try await env.reduceSetUp()
        await #expect(throws: SmokingError.invalidInput) {
            try await env.module.editQuitDate(newStartMs: ms("2026-03-01T08:00"))
        }
    }

    @Test("a start before the previous attempt ended is invalid, the same instant is allowed")
    func attemptsNeverOverlap() async throws {
        try await env.quitSetUp("2026-03-01T08:00")
        try await env.module.resolveSlip(units: 1, atMs: ms("2026-03-05T10:00"), restart: true)
        let before = try await env.input()

        await #expect(throws: SmokingError.invalidInput) {
            try await env.module.editQuitDate(newStartMs: ms("2026-03-05T10:00") - 1)
        }
        #expect(try await env.input() == before)

        try await env.module.editQuitDate(newStartMs: ms("2026-03-05T10:00"))
        #expect(try await env.input().attempts.last?.startedAtMs == ms("2026-03-05T10:00"))
    }
}
