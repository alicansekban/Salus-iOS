import Testing

@testable import SalusSmoking

@Suite("ResolveSlip", .timeLimit(.minutes(1)))
struct ResolveSlipTests {
    private let env: SmokingTestEnv

    init() throws {
        env = try SmokingTestEnv()
    }

    @Test("keeping the attempt logs the slip inside it and changes no attempt")
    func keepingTheAttempt() async throws {
        try await env.quitSetUp()
        let before = try await env.input().attempts

        let id = try await env.module.resolveSlip(units: 1, atMs: ms("2026-03-10T11:00"), restart: false)

        let input = try await env.input()
        #expect(input.attempts == before)
        let event = try #require(input.events.first)
        #expect(input.events.count == 1)
        #expect(event.id == id)
        #expect(event.type == .smoked)
        #expect(event.attemptId == before.first?.id)
    }

    @Test("restarting closes the attempt and opens the next one at the same instant")
    func restartingAtTheSameInstant() async throws {
        try await env.quitSetUp()
        let old = try #require(try await env.input().attempts.first)
        let atMs = ms("2026-03-10T11:00")

        try await env.module.resolveSlip(units: 2, atMs: atMs, restart: true)

        let input = try await env.input()
        #expect(input.attempts.count == 2)
        let closed = input.attempts[0]
        let fresh = input.attempts[1]
        #expect(closed.id == old.id)
        #expect(closed.endedAtMs == atMs)
        #expect(closed.endReason == .restarted)
        #expect(fresh.startedAtMs == atMs)
        #expect(fresh.endedAtMs == nil)
        #expect(fresh.endReason == nil)
        // The triggering event stays on the attempt it ended, although its instant is the new start.
        #expect(input.events.first?.attemptId == closed.id)
    }

    @Test("a restart before the attempt began is invalid and writes nothing")
    func restartBeforeTheStart() async throws {
        try await env.quitSetUp("2026-03-05T08:00")

        await #expect(throws: SmokingError.invalidInput) {
            try await env.module.resolveSlip(units: 1, atMs: ms("2026-03-05T07:00"), restart: true)
        }

        let input = try await env.input()
        #expect(input.attempts.count == 1)
        #expect(input.events.isEmpty)
    }

    @Test("it is a quit-only action")
    func quitOnly() async throws {
        await #expect(throws: SmokingError.notSetUp) {
            try await env.module.resolveSlip(units: 1, atMs: ms("2026-03-10T11:00"), restart: false)
        }

        try await env.reduceSetUp()
        await #expect(throws: SmokingError.invalidInput) {
            try await env.module.resolveSlip(units: 1, atMs: ms("2026-03-10T11:00"), restart: false)
        }
    }

    @Test("units must be at least one")
    func unitsAtLeastOne() async throws {
        try await env.quitSetUp()

        await #expect(throws: SmokingError.invalidInput) {
            try await env.module.resolveSlip(units: 0, atMs: ms("2026-03-10T11:00"), restart: false)
        }
    }
}
