import Foundation
import Testing

@testable import SalusSmoking

@Suite("EditEvent", .timeLimit(.minutes(1)))
struct EditEventTests {
    private let env: SmokingTestEnv

    init() throws {
        env = try SmokingTestEnv()
    }

    @Test("moving a slip before the attempt start detaches it and moving it back attaches it again")
    func movingAcrossTheStart() async throws {
        try await env.quitSetUp("2026-03-05T08:00")
        let id = try await env.module.logSmoked(units: 1, atMs: ms("2026-03-08T10:00"))
        let attemptId = try #require(try await env.input().attempts.first?.id)

        try await env.module.editEvent(
            eventId: id, atMs: ms("2026-03-04T10:00"), units: 1, trigger: nil, intensity: nil
        )
        #expect(try await env.input().events.first?.attemptId == nil)

        try await env.module.editEvent(
            eventId: id, atMs: ms("2026-03-09T10:00"), units: 1, trigger: nil, intensity: nil
        )
        #expect(try await env.input().events.first?.attemptId == attemptId)
    }

    @Test("the day is recomputed from the event's own zone, not the device's current one")
    func dayFromTheEventsOwnZone() async throws {
        try await env.reduceSetUp()
        let id = try await env.module.logSmoked(units: 1, atMs: ms("2026-03-10T10:00"))
        let losAngeles = try #require(TimeZone(identifier: "America/Los_Angeles"))
        env.at("2026-03-10T12:00", losAngeles)
        // 00:30 on the 10th in Istanbul is still the 9th in Los Angeles.
        let atMs = ms("2026-03-10T00:30")

        try await env.module.editEvent(eventId: id, atMs: atMs, units: 3, trigger: .social, intensity: 2)

        let event = try #require(try await env.input().events.first)
        #expect(event.tzId == "Europe/Istanbul")
        #expect(event.epochDay == day("2026-03-10"))
        #expect(event.units == 3)
        #expect(event.trigger == .social)
        #expect(event.intensity == 2)
        #expect(event.occurredAtMs == atMs)
    }

    @Test("a craving keeps a null unit count")
    func cravingKeepsNullUnits() async throws {
        try await env.quitSetUp()
        let id = try await env.module.logCravingResisted(atMs: ms("2026-03-10T11:00"))

        try await env.module.editEvent(
            eventId: id, atMs: ms("2026-03-10T11:30"), units: 5, trigger: .boredom, intensity: 1
        )

        let event = try #require(try await env.input().events.first)
        #expect(event.units == nil)
        #expect(event.trigger == .boredom)
    }

    @Test("a slip moved onto a day that has a none-today marker replaces the marker")
    func movedSlipReplacesTheMarker() async throws {
        try await env.reduceSetUp()
        try await env.module.logNoneToday() // today, 10 March
        let id = try await env.module.logSmoked(units: 1, atMs: ms("2026-03-09T10:00"))

        try await env.module.editEvent(
            eventId: id, atMs: ms("2026-03-10T09:00"), units: 1, trigger: nil, intensity: nil
        )

        #expect(try await env.input().events.map(\.units) == [1])
    }

    @Test("an unknown event, a slip with no units or a bad intensity is invalid and changes nothing")
    func invalidEdits() async throws {
        try await env.reduceSetUp()
        let id = try await env.module.logSmoked(units: 1, atMs: ms("2026-03-10T10:00"))

        await #expect(throws: SmokingError.invalidInput) {
            try await env.module.editEvent(
                eventId: "missing", atMs: ms("2026-03-10T10:00"), units: 1, trigger: nil, intensity: nil
            )
        }
        await #expect(throws: SmokingError.invalidInput) {
            try await env.module.editEvent(
                eventId: id, atMs: ms("2026-03-10T10:00"), units: 0, trigger: nil, intensity: nil
            )
        }
        await #expect(throws: SmokingError.invalidInput) {
            try await env.module.editEvent(
                eventId: id, atMs: ms("2026-03-10T10:00"), units: 1, trigger: nil, intensity: 9
            )
        }
        #expect(try await env.input().events.first?.units == 1)
    }

    @Test("a none-today marker edited into a real entry becomes that entry, not nothing")
    func markerBecomesAnEntry() async throws {
        try await env.reduceSetUp()
        try await env.module.logNoneToday()
        let marker = try #require(try await env.input().events.first)

        try await env.module.editEvent(
            eventId: marker.id, atMs: marker.occurredAtMs, units: 2, trigger: nil, intensity: nil
        )

        let event = try #require(try await env.input().events.first)
        #expect(event.id == marker.id)
        #expect(event.units == 2)
        #expect(event.epochDay == marker.epochDay)
    }

    @Test("a marker's time can be edited and it stays a marker on its new day")
    func markerStaysAMarker() async throws {
        try await env.reduceSetUp()
        try await env.module.logNoneToday()
        let marker = try #require(try await env.input().events.first)

        try await env.module.editEvent(
            eventId: marker.id, atMs: ms("2026-03-09T10:00"), units: 0, trigger: nil, intensity: nil
        )

        let event = try #require(try await env.input().events.first)
        #expect(event.units == 0)
        #expect(event.epochDay == day("2026-03-09"))
    }

    @Test("a replaced marker that still carries an attempt link does not break the edit")
    func replacedMarkerWithAStaleLink() async throws {
        try await env.quitSetUp("2026-03-01T08:00")
        let attemptId = try #require(try await env.input().attempts.first?.id)
        let entry = try await env.module.logSmoked(units: 1, atMs: ms("2026-03-09T10:00"))
        // A marker the use cases would never write: zero units yet attached to an attempt.
        try await env.dao.insertEvent(
            SmokingEventRecordFixture.marker(
                id: "stale-marker",
                atMs: ms("2026-03-10T08:00"),
                epochDay: day("2026-03-10"),
                attemptId: attemptId
            )
        )

        try await env.module.editEvent(
            eventId: entry, atMs: ms("2026-03-10T09:00"), units: 1, trigger: nil, intensity: nil
        )

        #expect(try await env.input().events.map(\.id) == [entry])
    }

    @Test("a marker cannot move onto a day that already has an entry")
    func markerCannotJoinAnEntry() async throws {
        try await env.reduceSetUp()
        try await env.module.logSmoked(units: 1, atMs: ms("2026-03-09T10:00"))
        try await env.module.logNoneToday()
        let marker = try #require(try await env.input().events.first { $0.units == 0 })

        await #expect(throws: SmokingError.invalidInput) {
            try await env.module.editEvent(
                eventId: marker.id, atMs: ms("2026-03-09T20:00"), units: 0, trigger: nil, intensity: nil
            )
        }

        let kept = try #require(try await env.input().events.first { $0.id == marker.id })
        #expect(kept.epochDay == day("2026-03-10"))
    }
}

@Suite("DeleteEvent", .timeLimit(.minutes(1)))
struct DeleteEventTests {
    private let env: SmokingTestEnv

    init() throws {
        env = try SmokingTestEnv()
    }

    @Test("it deletes exactly the event it is given, also after midnight")
    func exactlyThatEventAfterMidnight() async throws {
        try await env.reduceSetUp()
        env.at("2026-03-10T23:50")
        let first = try await env.module.logSmoked(units: 1, atMs: ms("2026-03-10T23:50"))
        let second = try await env.module.logSmoked(units: 1, atMs: ms("2026-03-10T23:51"))
        env.at("2026-03-11T00:05")

        try await env.module.deleteEvent(eventId: first)

        #expect(try await env.input().events.map(\.id) == [second])
    }

    @Test("deleting an unknown or already deleted id succeeds and changes nothing")
    func idempotentUndo() async throws {
        try await env.reduceSetUp()
        let id = try await env.module.logSmoked(units: 1, atMs: ms("2026-03-10T10:00"))
        try await env.module.deleteEvent(eventId: id)

        try await env.module.deleteEvent(eventId: id)

        #expect(try await env.input().events.isEmpty)
    }

    @Test("it re-derives the attempt of the entries that remain")
    func rederivesRemainingEntries() async throws {
        try await env.quitSetUp("2026-03-01T08:00")
        let doomed = try await env.module.logSmoked(units: 1, atMs: ms("2026-03-09T10:00"))
        // A slip stored without its attempt link although it lies inside the attempt.
        try await env.dao.insertEvent(
            SmokingEventRecordFixture.slip(id: "stale", atMs: ms("2026-03-04T10:00"), attemptId: nil)
        )

        try await env.module.deleteEvent(eventId: doomed)

        let input = try await env.input()
        let stale = try #require(input.events.first { $0.id == "stale" })
        #expect(stale.attemptId == input.attempts.first?.id)
    }
}
