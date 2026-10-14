import Foundation
import Testing

@testable import SalusSmoking

@Suite("LogSmoked", .timeLimit(.minutes(1)))
struct LogSmokedTests {
    private let env: SmokingTestEnv

    init() throws {
        env = try SmokingTestEnv()
    }

    @Test("it returns the event id and stores the event with its own zone and day")
    func ownZoneAndDay() async throws {
        let losAngeles = try #require(TimeZone(identifier: "America/Los_Angeles"))
        try await env.reduceSetUp()
        env.at("2026-03-10T23:40", losAngeles)
        let atMs = ms("2026-03-10T23:30", losAngeles) // 06:30 UTC the next day

        let id = try await env.module.logSmoked(units: 2, atMs: atMs, trigger: .coffee, intensity: 4)

        let event = try #require(try await env.input().events.first)
        #expect(event.id == id)
        #expect(event.type == .smoked)
        #expect(event.units == 2)
        #expect(event.trigger == .coffee)
        #expect(event.intensity == 4)
        #expect(event.tzId == "America/Los_Angeles")
        #expect(event.epochDay == day("2026-03-10")) // not the UTC day
        #expect(event.occurredAtMs == atMs)
        #expect(event.productType == .cigarette)
    }

    @Test("the first plus one of a day removes that day's none-today marker, other days keep theirs")
    func firstPlusOneRemovesTheMarker() async throws {
        try await env.reduceSetUp()
        try await env.module.logNoneToday()
        env.at("2026-03-11T09:00")
        try await env.module.logNoneToday()
        env.at("2026-03-10T15:00")

        try await env.module.logSmoked(units: 1, atMs: ms("2026-03-10T15:00"))

        let events = try await env.input().events
        #expect(events.map(\.epochDay) == [day("2026-03-10"), day("2026-03-11")])
        #expect(events.map(\.units) == [1, 0])
    }

    @Test("a slip in a quit attempt keeps the attempt open and attaches to it")
    func quitSlipAttaches() async throws {
        try await env.quitSetUp()

        try await env.module.logSmoked(units: 1, atMs: ms("2026-03-10T11:00"))

        let input = try await env.input()
        let attempt = try #require(input.attempts.first)
        #expect(attempt.endedAtMs == nil)
        #expect(input.events.first?.attemptId == attempt.id)
    }

    @Test("a back-dated entry before the attempt start is not attached to it")
    func backDatedEntry() async throws {
        try await env.quitSetUp("2026-03-05T08:00")

        try await env.module.logSmoked(units: 1, atMs: ms("2026-03-04T20:00"))

        #expect(try await env.input().events.first?.attemptId == nil)
    }

    @Test("a reduce entry carries no attempt")
    func reduceEntryHasNoAttempt() async throws {
        try await env.reduceSetUp()

        try await env.module.logSmoked(units: 1, atMs: ms("2026-03-10T11:00"))

        #expect(try await env.input().events.first?.attemptId == nil)
    }

    @Test("it fails when nothing is set up and for invalid input, writing nothing")
    func failures() async throws {
        await #expect(throws: SmokingError.notSetUp) {
            try await env.module.logSmoked(units: 1, atMs: ms("2026-03-10T11:00"))
        }

        try await env.reduceSetUp()
        await #expect(throws: SmokingError.invalidInput) {
            try await env.module.logSmoked(units: 0, atMs: ms("2026-03-10T11:00"))
        }
        await #expect(throws: SmokingError.invalidInput) {
            try await env.module.logSmoked(units: 1, atMs: ms("2026-03-10T11:00"), intensity: 6)
        }
        #expect(try await env.input().events.isEmpty)
    }

    @Test("it notifies the listener once per write")
    func notifiesOncePerWrite() async throws {
        try await env.reduceSetUp()
        let before = env.notifications.value

        try await env.module.logSmoked(units: 1, atMs: ms("2026-03-10T11:00"))

        #expect(env.notifications.value == before + 1)
    }
}

@Suite("LogNoneToday", .timeLimit(.minutes(1)))
struct LogNoneTodayTests {
    private let env: SmokingTestEnv

    init() throws {
        env = try SmokingTestEnv()
    }

    @Test("it writes a zero marker for today")
    func writesAMarker() async throws {
        try await env.reduceSetUp()

        try await env.module.logNoneToday()

        let event = try #require(try await env.input().events.first)
        #expect(event.type == .smoked)
        #expect(event.units == 0)
        #expect(event.epochDay == day("2026-03-10"))
        #expect(event.occurredAtMs == ms("2026-03-10T12:00"))
        #expect(event.attemptId == nil)
    }

    @Test("a second tap, or a day that already has an entry, writes nothing and tells nobody")
    func doubleTapWritesOnce() async throws {
        try await env.reduceSetUp()
        try await env.module.logNoneToday()
        let notified = env.notifications.value

        try await env.module.logNoneToday()

        #expect(try await env.input().events.count == 1)
        #expect(env.notifications.value == notified)

        let other = try SmokingTestEnv()
        try await other.reduceSetUp()
        try await other.module.logSmoked(units: 1, atMs: ms("2026-03-10T09:00"))
        try await other.module.logNoneToday()
        #expect(try await other.input().events.count == 1)
    }

    @Test("it is a reduce-only action")
    func reduceOnly() async throws {
        await #expect(throws: SmokingError.notSetUp) {
            try await env.module.logNoneToday()
        }

        try await env.quitSetUp()
        await #expect(throws: SmokingError.invalidInput) {
            try await env.module.logNoneToday()
        }
    }
}

@Suite("LogCravingResisted", .timeLimit(.minutes(1)))
struct LogCravingResistedTests {
    private let env: SmokingTestEnv

    init() throws {
        env = try SmokingTestEnv()
    }

    @Test("it stores a craving with no units and attaches it to the attempt that holds it")
    func storesACraving() async throws {
        try await env.quitSetUp()

        let id = try await env.module.logCravingResisted(atMs: ms("2026-03-10T11:00"), trigger: .stress, intensity: 3)

        let input = try await env.input()
        let event = try #require(input.events.first)
        #expect(event.id == id)
        #expect(event.type == .cravingResisted)
        #expect(event.units == nil)
        #expect(event.trigger == .stress)
        #expect(event.intensity == 3)
        #expect(event.attemptId == input.attempts.first?.id)
    }

    @Test("without a plan, or with an intensity out of range, it fails")
    func failures() async throws {
        await #expect(throws: SmokingError.notSetUp) {
            try await env.module.logCravingResisted(atMs: ms("2026-03-10T11:00"))
        }

        try await env.quitSetUp()
        await #expect(throws: SmokingError.invalidInput) {
            try await env.module.logCravingResisted(atMs: ms("2026-03-10T11:00"), intensity: 0)
        }
        #expect(try await env.input().events.isEmpty)
    }
}
