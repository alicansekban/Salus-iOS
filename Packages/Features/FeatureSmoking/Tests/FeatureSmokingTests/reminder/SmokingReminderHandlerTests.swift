// The reminder engine's view of the smoking plan (contract section 4, with the section 8.13 delivery
// anchoring). Ported from Android's `SmokingReminderHandlerTest.kt`: every instant is an Istanbul
// wall-clock string (UTC+3 all year), so a test reads like the scenario it checks.
//
// The quit scenario: a 20-a-day smoker quits at 09:00 on 10 March 2026. Hand-worked from the
// contract: 20 minutes is due at 09:20 and 12 hours at 21:00, both in the first 48 h, so the day
// carries two notifications; "1 day" is due at 09:00 the next day.

import Foundation
import SalusModel
import SalusReminder
import SalusSmoking
import SalusTesting
import Testing

@testable import FeatureSmoking

@Suite("Smoking reminder handler")
struct SmokingReminderHandlerTests {
    private typealias Fix = SmokingReminderFixtures

    private let clock = FixedSalusClock(now: Fix.at("2026-03-10T09:00"), timeZone: Fix.zone)
    private let repository = InputSwappingSmokingRepository(Fix.quitInput())
    private let handler: SmokingReminderHandler

    init() {
        handler = SmokingReminderHandler(
            repository: repository,
            clock: clock,
            strings: FakeSmokingNotificationStrings()
        )
    }

    private func keysAndTriggers(_ occurrences: [ReminderOccurrence]) -> [String] {
        occurrences.map { "\($0.occurrenceKey)@\($0.triggerAt.epochMilliseconds)" }
    }

    private func expected(_ pairs: (String, String)...) -> [String] {
        pairs.map { "\($0.0)@\(Fix.ms($0.1))" }
    }

    // MARK: - Occurrences

    @Test("occurrences are the scheduler's notifications inside the window")
    func occurrencesAreTheSchedulersNotifications() async throws {
        let from = Fix.at("2026-03-10T09:05")
        let until = Fix.at("2026-03-11T09:05")

        let occurrences = try await handler.occurrencesBetween(from: from, until: until)

        #expect(keysAndTriggers(occurrences) == expected(
            ("q:a1:2026-03-10:early", "2026-03-10T09:20"),
            ("q:a1:2026-03-10", "2026-03-10T21:00"),
            ("q:a1:2026-03-11", "2026-03-11T09:00")
        ))
        #expect(occurrences.map(\.entityId) == ["smoking:h_20m", "smoking:h_12h", "smoking"])
        // And it is the scheduler's own output, not a second implementation of it.
        let planned = MilestoneScheduler
            .plan(Fix.quitInput(), nowMs: from.epochMilliseconds, zone: Fix.zone)
            .filter { $0.triggerAtMs < until.epochMilliseconds }
        #expect(planned.map(\.key) == occurrences.map(\.occurrenceKey))
    }

    @Test("the end of the window is exclusive")
    func endOfWindowIsExclusive() async throws {
        let occurrences = try await handler.occurrencesBetween(
            from: Fix.at("2026-03-10T09:05"),
            until: Fix.at("2026-03-10T21:00")
        )

        #expect(occurrences.map(\.occurrenceKey) == ["q:a1:2026-03-10:early"])
    }

    @Test("an empty or reversed window schedules nothing")
    func emptyWindowSchedulesNothing() async throws {
        let instant = Fix.at("2026-03-10T09:05")

        #expect(try await handler.occurrencesBetween(from: instant, until: instant).isEmpty)
        #expect(try await handler.occurrencesBetween(from: instant, until: Fix.at("2026-03-10T09:00")).isEmpty)
    }

    @Test("nothing is scheduled while notifications are off")
    func nothingWhileNotificationsAreOff() async throws {
        repository.input = Fix.quitInput(notifications: false)

        let occurrences = try await handler.occurrencesBetween(
            from: Fix.at("2026-03-10T09:05"),
            until: Fix.at("2026-03-20T09:05")
        )

        #expect(occurrences.isEmpty)
    }

    @Test("nothing is scheduled before a plan exists")
    func nothingBeforeAPlan() async throws {
        repository.input = Fix.empty

        let occurrences = try await handler.occurrencesBetween(
            from: Fix.at("2026-03-10T09:05"),
            until: Fix.at("2026-03-20T09:05")
        )

        #expect(occurrences.isEmpty)
    }

    @Test("a reduce plan schedules its evening reminders at 20:30")
    func reducePlanSchedulesEvenings() async throws {
        repository.input = Fix.reduceInput(evening: true)

        let occurrences = try await handler.occurrencesBetween(
            from: Fix.at("2026-03-10T12:00"),
            until: Fix.at("2026-03-12T12:00")
        )

        #expect(keysAndTriggers(occurrences) == expected(
            ("r:p1:2026-03-10", "2026-03-10T20:30"),
            ("r:p1:2026-03-11", "2026-03-11T20:30")
        ))
        #expect(occurrences.map(\.entityId) == ["smoking", "smoking"])
    }

    @Test("a reduce plan without the evening reminder schedules nothing")
    func reducePlanWithoutEveningSchedulesNothing() async throws {
        repository.input = Fix.reduceInput(evening: false)

        let occurrences = try await handler.occurrencesBetween(
            from: Fix.at("2026-03-10T12:00"),
            until: Fix.at("2026-03-17T12:00")
        )

        #expect(occurrences.isEmpty)
    }

    // MARK: - Section 8.13: delivery anchoring

    /// Quit 09:00 on the 10th, slip 08:30 on the 11th. The 11th is inside the first 48 h and has
    /// three instants: 20 minutes at 08:50, "1 day" at 09:00 and 12 hours at 20:30. The engine
    /// re-syncs after every fired alarm; planned as of that moment the remaining two instants would
    /// split again, minting a third notification that repeats "20 dakika".
    @Test("syncing after an early notification fired does not split its day again")
    func syncAfterEarlyDoesNotMintAThirdNotification() async throws {
        repository.input = Fix.quitInput(events: [Fix.smoked("e1", Fix.ms("2026-03-11T08:30"))])

        let beforeEarly = try await handler.occurrencesBetween(
            from: Fix.at("2026-03-11T08:00"),
            until: Fix.at("2026-03-12T08:00")
        )
        #expect(keysAndTriggers(beforeEarly) == expected(
            ("q:a1:2026-03-11:early", "2026-03-11T08:50"),
            ("q:a1:2026-03-11", "2026-03-11T20:30")
        ))

        clock.advanceTo(Fix.at("2026-03-11T08:50:01"))
        let early = try await handler.notificationContent(for: Fix.ref("q:a1:2026-03-11:early"))
        #expect(early?.title == "stage:h_20m")

        let afterEarly = try await handler.occurrencesBetween(
            from: Fix.at("2026-03-11T08:50:01"),
            until: Fix.at("2026-03-12T08:50:01")
        )
        #expect(afterEarly.map(\.occurrenceKey).filter { $0.contains("03-11") } == ["q:a1:2026-03-11"])

        clock.advanceTo(Fix.at("2026-03-11T20:30:01"))
        let second = try await handler.notificationContent(for: Fix.ref("q:a1:2026-03-11"))
        #expect(second?.title == "days:1")
        #expect(second?.text == "stage:h_12h")
    }

    /// 12 hours was due at 21:00 on the 10th; a slip at 20:00 moves it to 08:00 on the 11th.
    @Test("a slip that moves a stage past tonight leaves today's key without that stage")
    func slipMovesAStagePastTonight() async throws {
        repository.input = Fix.quitInput(events: [Fix.smoked("e1", Fix.ms("2026-03-10T20:00"))])
        clock.advanceTo(Fix.at("2026-03-10T21:00:30"))

        let content = try await handler.notificationContent(for: Fix.ref("q:a1:2026-03-10"))

        #expect(content?.title == "stage:h_20m")
        #expect(content?.text != "stage:h_12h")
    }

    /// Quit 10:00: 12 hours is due at 22:00 sharp, inside quiet hours, so it moves to 08:00 on the
    /// 11th, where it is the early notification of that day. Planned as of the start of the 11th
    /// (or from 23:00 the evening before) it would not be found.
    @Test("a stage whose quiet-hours instant moves it to the next morning still fires on that morning")
    func quietHoursStageFiresNextMorning() async throws {
        repository.input = Fix.quitInput(startMs: Fix.ms("2026-03-10T10:00"))

        let occurrences = try await handler.occurrencesBetween(
            from: Fix.at("2026-03-10T10:05"),
            until: Fix.at("2026-03-11T09:00")
        )
        #expect(keysAndTriggers(occurrences) == expected(
            ("q:a1:2026-03-10", "2026-03-10T10:20"),
            ("q:a1:2026-03-11:early", "2026-03-11T08:00")
        ))

        clock.advanceTo(Fix.at("2026-03-11T08:00:30"))
        let content = try await handler.notificationContent(for: Fix.ref("q:a1:2026-03-11:early"))
        #expect(content?.title == "stage:h_12h")
    }

    @Test("the same holds for a stage due late in the evening")
    func lateEveningStageFiresNextMorning() async throws {
        repository.input = Fix.quitInput(startMs: Fix.ms("2026-03-10T11:30"))
        clock.advanceTo(Fix.at("2026-03-11T08:00:30"))

        let content = try await handler.notificationContent(for: Fix.ref("q:a1:2026-03-11:early"))

        #expect(content?.title == "stage:h_12h")
    }

    /// The quit-day anchor is the later of the evening before and the attempt start, so a
    /// fast-projecting plan's units and money count from the quit date, not from 22:00 the evening
    /// before it. An earlier, closed attempt is there to show that it is the ACTIVE attempt's start.
    @Test("a notification of the quit day is planned from the quit date, not from the evening before it")
    func quitDayIsAnchoredAtTheQuitDate() async throws {
        let closed = QuitAttempt(
            id: "a0",
            startedAtMs: Fix.ms("2026-03-01T08:30"),
            tzId: Fix.zone.identifier,
            endedAtMs: Fix.ms("2026-03-10T08:30"),
            endReason: .restarted
        )
        repository.input = Fix.quitInput(
            startMs: Fix.ms("2026-03-10T08:30"),
            baseline: 240,
            earlierAttempts: [closed]
        )
        clock.advanceTo(Fix.at("2026-03-10T08:50:30"))

        let content = try await handler.notificationContent(for: Fix.ref("q:a1:2026-03-10:early"))

        #expect(content?.title == "stage:h_20m")
    }

    // MARK: - Content at fire time

    @Test("a fired milestone is announced as a plain notification without actions")
    func firedMilestoneIsAPlainNotification() async throws {
        clock.advanceTo(Fix.at("2026-03-10T09:20:30"))

        let content = try #require(try await handler.notificationContent(for: Fix.ref("q:a1:2026-03-10:early")))

        #expect(content.presentation == .notification)
        #expect(content.actions.isEmpty)
        #expect(content.title == "stage:h_20m")
        #expect(content.text == "stage-hint")
    }

    @Test("the second notification of a day announces what the first did not")
    func secondNotificationAnnouncesTheRest() async throws {
        clock.advanceTo(Fix.at("2026-03-10T21:00:30"))

        let content = try await handler.notificationContent(for: Fix.ref("q:a1:2026-03-10"))

        #expect(content?.title == "stage:h_12h")
    }

    @Test("a day milestone is announced with the day count")
    func dayMilestoneIsAnnounced() async throws {
        clock.advanceTo(Fix.at("2026-03-11T09:00:30"))

        let content = try await handler.notificationContent(for: Fix.ref("q:a1:2026-03-11"))

        #expect(content?.title == "days:1")
    }

    @Test("a reset leaves nothing to announce")
    func resetLeavesNothing() async throws {
        clock.advanceTo(Fix.at("2026-03-10T09:20:30"))
        repository.input = Fix.empty

        #expect(try await handler.notificationContent(for: Fix.ref("q:a1:2026-03-10:early")) == nil)
    }

    @Test("switching from quit to reduce leaves nothing to announce")
    func switchToReduceLeavesNothing() async throws {
        clock.advanceTo(Fix.at("2026-03-10T09:20:30"))
        repository.input = Fix.reduceInput(
            evening: false,
            attempts: [QuitAttempt(
                id: "a1",
                startedAtMs: Fix.ms("2026-03-10T09:00"),
                tzId: Fix.zone.identifier,
                endedAtMs: Fix.ms("2026-03-10T09:10"),
                endReason: .switchedToReduce
            )]
        )

        #expect(try await handler.notificationContent(for: Fix.ref("q:a1:2026-03-10:early")) == nil)
    }

    @Test("turning notifications off after scheduling silences the fired one")
    func notificationsOffSilencesTheFiredOne() async throws {
        clock.advanceTo(Fix.at("2026-03-10T09:20:30"))
        repository.input = Fix.quitInput(notifications: false)

        #expect(try await handler.notificationContent(for: Fix.ref("q:a1:2026-03-10:early")) == nil)
    }

    @Test("a key from an earlier attempt is not announced for the current one")
    func earlierAttemptKeyIsNotAnnounced() async throws {
        clock.advanceTo(Fix.at("2026-03-10T09:20:30"))

        #expect(try await handler.notificationContent(for: Fix.ref("q:old-attempt:2026-03-10:early")) == nil)
    }

    /// Smoked at 09:10: the 20-minute stage now counts from there and is due at 09:30. Android's
    /// receiver asks at 09:20:30 and drops the stage; iOS bakes at sync time (see the handler's
    /// header), so the same data answers with the key's MOVED instant and a text that is true then.
    @Test("a slip that moved the stage moves the key's instant and re-bakes the stage for it")
    func slipMovesTheKeyInsteadOfAnnouncingEarly() async throws {
        repository.input = Fix.quitInput(events: [Fix.smoked("e1", Fix.ms("2026-03-10T09:10"))])
        clock.advanceTo(Fix.at("2026-03-10T09:20:30"))

        let occurrences = try await handler.occurrencesBetween(
            from: Fix.at("2026-03-10T09:20:30"),
            until: Fix.at("2026-03-10T10:00")
        )
        let content = try await handler.notificationContent(for: Fix.ref("q:a1:2026-03-10:early"))

        #expect(keysAndTriggers(occurrences) == expected(("q:a1:2026-03-10:early", "2026-03-10T09:30")))
        #expect(content?.title == "stage:h_20m")
    }

    /// The quit date was moved to 10:00 after the notification for "1 day" was scheduled at 09:00:
    /// the key is re-planned at 10:00 on the 11th, and its text counts from the new date.
    @Test("a moved quit date moves the day milestone's instant")
    func movedQuitDateMovesTheDayMilestone() async throws {
        repository.input = Fix.quitInput(startMs: Fix.ms("2026-03-10T10:00"))
        clock.advanceTo(Fix.at("2026-03-11T09:00:30"))

        let occurrences = try await handler.occurrencesBetween(
            from: Fix.at("2026-03-11T09:00:30"),
            until: Fix.at("2026-03-11T11:00")
        )
        let content = try await handler.notificationContent(for: Fix.ref("q:a1:2026-03-11"))

        #expect(keysAndTriggers(occurrences) == expected(("q:a1:2026-03-11", "2026-03-11T10:00")))
        #expect(content?.title == "days:1")
    }

    @Test("an evening reminder is dropped when the day already has an entry")
    func eveningDroppedWhenTheDayHasAnEntry() async throws {
        repository.input = Fix.reduceInput(
            evening: true,
            events: [Fix.smoked("e1", Fix.ms("2026-03-10T14:00"), attemptId: nil)]
        )
        clock.advanceTo(Fix.at("2026-03-10T20:30:30"))

        #expect(try await handler.notificationContent(for: Fix.ref("r:p1:2026-03-10")) == nil)
    }

    @Test("an evening reminder is dropped when the day already has a none-today marker")
    func eveningDroppedWhenTheDayHasANoneTodayMarker() async throws {
        repository.input = Fix.reduceInput(
            evening: true,
            events: [Fix.smoked("e1", Fix.ms("2026-03-10T08:00"), attemptId: nil, units: 0)]
        )
        clock.advanceTo(Fix.at("2026-03-10T20:30:30"))

        #expect(try await handler.notificationContent(for: Fix.ref("r:p1:2026-03-10")) == nil)
    }

    /// A resisted craving is not a log of the day, and yesterday's entry is not today's.
    @Test("an evening reminder fires on a day without an entry")
    func eveningFiresOnADayWithoutAnEntry() async throws {
        repository.input = Fix.reduceInput(
            evening: true,
            events: [
                Fix.smoked("e1", Fix.ms("2026-03-09T14:00"), attemptId: nil),
                Fix.craving("c1", Fix.ms("2026-03-10T14:00"))
            ]
        )
        clock.advanceTo(Fix.at("2026-03-10T20:30:30"))

        let content = try await handler.notificationContent(for: Fix.ref("r:p1:2026-03-10"))

        #expect(content?.title == "evening-title")
        #expect(content?.presentation == .notification)
    }

    @Test("an evening reminder is dropped when the plan switched to quit")
    func eveningDroppedWhenThePlanSwitchedToQuit() async throws {
        repository.input = Fix.quitInput()
        clock.advanceTo(Fix.at("2026-03-10T20:30:30"))

        #expect(try await handler.notificationContent(for: Fix.ref("r:p1:2026-03-10")) == nil)
    }

    @Test("a key it does not understand is not announced")
    func unknownKeysAreNotAnnounced() async throws {
        #expect(try await handler.notificationContent(for: Fix.ref("garbage")) == nil)
        #expect(try await handler.notificationContent(for: Fix.ref("q:a1:not-a-date")) == nil)
        #expect(try await handler.notificationContent(for: Fix.ref("x:a1:2026-03-10")) == nil)
        #expect(try await handler.notificationContent(for: Fix.ref("q:a1:2026-03-10:late")) == nil)
        #expect(try await handler.notificationContent(for: Fix.ref("q:a1:2026-03-10:early:x")) == nil)
    }
}
