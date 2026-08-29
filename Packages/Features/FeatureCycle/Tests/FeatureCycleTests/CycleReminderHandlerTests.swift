// Ported 1:1 from `feature/cycle/src/test/kotlin/com/alicansekban/salus/feature/cycle/reminder/
// CycleReminderHandlerTest.kt`.
//
// Seven cases, in the Kotlin order, with the Kotlin fixture (`Europe/Istanbul`, the fixed instant
// 1_755_000_000_000 ms = 2025-08-12 local, four regular 28-day cycles ending 2025-08-05, and a
// 60-day window) and the Kotlin expectations. Each one cites the Kotlin line it comes from, so a
// change on either side that is not made on the other is visible in the diff.
//
// Kotlin's fixture reads `context.getString` through an anonymous `CycleNotificationTexts`; the
// Swift twin injects the same two stub strings for the reason `MedicationReminderHandlerTests`
// already documents — `swift test` copies a `.xcstrings` into the resource bundle verbatim rather
// than compiling it, so a live lookup would answer with the key.
//
// The expected trigger is composed from date components in the fixture's zone
// (`LocalDateTime.instant(in:)`, the twin of Kotlin's `atTime(...).toInstant(zone)`), never from a
// hard-coded epoch: a hard-coded number would pass even if the zone handling were wrong.

import Foundation
import SalusCommon
import SalusModel
import SalusReminder
import SalusTesting
import Testing

@testable import FeatureCycle

/// The stub of `CycleReminderHandlerTest.kt:37-41` — copy the handler never has to resolve.
private struct StubCycleNotificationTexts: CycleNotificationTexts {
    func title() -> String {
        "title"
    }

    func body(leadDays: Int) -> String {
        "body:\(leadDays)"
    }
}

@Suite("CycleReminderHandler")
struct CycleReminderHandlerTests {
    /// `CycleReminderHandlerTest.kt:28` — `TimeZone.of("Europe/Istanbul")`.
    private static let zone = FixedSalusClock.defaultZone
    /// `CycleReminderHandlerTest.kt:31, 73` — 2025-08-12 local time in Istanbul.
    private static let windowFrom = Date(epochMilliseconds: 1_755_000_000_000)
    /// `CycleReminderHandlerTest.kt:74` — `windowFrom + 60d`.
    private static let windowUntil = windowFrom.addingTimeInterval(60 * 24 * 3600)

    private let repository: FakeCycleRepository
    private let settings: FakeCycleReminderSettings
    private let clock: FixedSalusClock
    private let handler: CycleReminderHandler

    init() {
        // `CycleReminderHandlerTest.kt:33-50`.
        let repository = FakeCycleRepository()
        let settings = FakeCycleReminderSettings(
            initial: CycleReminderConfig(enabled: true, leadDays: 1, minuteOfDay: 9 * 60)
        )
        let clock = FixedSalusClock(now: Self.windowFrom, timeZone: Self.zone)
        self.repository = repository
        self.settings = settings
        self.clock = clock
        handler = CycleReminderHandler(
            repository: repository,
            predictor: CyclePredictor(),
            settings: settings,
            clock: clock,
            texts: StubCycleNotificationTexts()
        )
    }

    /// A completed 5-day period record, the shape Kotlin's `mapIndexed` builds
    /// (`CycleReminderHandlerTest.kt:60-69`). Kotlin spells the end date
    /// `LocalDate(start.year, start.month, start.day + 4)`; none of the fixture's starts is late
    /// enough in its month for that to differ from `+4 days`.
    private func period(id: String, start: LocalDate) -> CyclePeriod {
        CyclePeriod(
            id: id,
            startDate: start,
            endDate: start.plusDays(4),
            flowPeak: nil,
            note: nil,
            createdAt: clock.now()
        )
    }

    /// Four regular 28-day cycles, last start 2025-08-05 → predicted next start 2025-09-02
    /// (`CycleReminderHandlerTest.kt:51-71`).
    ///
    /// Kotlin spreads an array into the fake's vararg setter; Swift has no splat, so the four
    /// records are passed by position.
    private func seedRegularPeriods() {
        repository.setPeriods(
            period(id: "p0", start: LocalDate(year: 2025, month: 5, day: 13)),
            period(id: "p1", start: LocalDate(year: 2025, month: 6, day: 10)),
            period(id: "p2", start: LocalDate(year: 2025, month: 7, day: 8)),
            period(id: "p3", start: LocalDate(year: 2025, month: 8, day: 5))
        )
    }

    /// The instant at which `date` reads `09:00` in the fixture's zone — Kotlin's
    /// `date.atTime(LocalTime(9, 0)).toInstant(zone)`.
    private static func nineInTheMorning(on date: LocalDate) -> Date {
        LocalDateTime(date: date, minuteOfDay: 9 * 60).instant(in: zone)
    }

    /// `CycleReminderHandlerTest.kt:76-89`.
    @Test("emits one occurrence one day before the predicted start at the configured time")
    func emitsOneOccurrenceOneDayBeforeThePredictedStartAtTheConfiguredTime() async throws {
        seedRegularPeriods()

        let occurrences = try await handler.occurrencesBetween(
            from: Self.windowFrom,
            until: Self.windowUntil
        )

        // Predicted start 2025-09-02, lead 1 day.
        let expectedDate = LocalDate(year: 2025, month: 9, day: 1)
        #expect(occurrences.count == 1)
        let occurrence = try #require(occurrences.first)
        #expect(occurrence.entityId == "cycle-period")
        #expect(occurrence.triggerAt == Self.nineInTheMorning(on: expectedDate))
        #expect(occurrence.occurrenceKey == "2025-09-01|540")
    }

    /// `CycleReminderHandlerTest.kt:91-102`.
    @Test("lead days shift the trigger date")
    func leadDaysShiftTheTriggerDate() async throws {
        seedRegularPeriods()
        settings.setLeadDays(3)

        let occurrences = try await handler.occurrencesBetween(
            from: Self.windowFrom,
            until: Self.windowUntil
        )

        #expect(occurrences.count == 1)
        let occurrence = try #require(occurrences.first)
        #expect(
            occurrence.triggerAt
                == Self.nineInTheMorning(on: LocalDate(year: 2025, month: 8, day: 30))
        )
    }

    /// `CycleReminderHandlerTest.kt:104-110`.
    @Test("emits nothing while the toggle is off")
    func emitsNothingWhileTheToggleIsOff() async throws {
        seedRegularPeriods()
        settings.setEnabled(false)

        let occurrences = try await handler.occurrencesBetween(
            from: Self.windowFrom,
            until: Self.windowUntil
        )

        #expect(occurrences.isEmpty)
    }

    /// `CycleReminderHandlerTest.kt:112-121`.
    @Test("emits nothing on LOW confidence")
    func emitsNothingOnLowConfidence() async throws {
        // Only two starts -> one usable cycle -> LOW confidence.
        repository.setPeriods(
            period(id: "p0", start: LocalDate(year: 2025, month: 7, day: 8)),
            period(id: "p1", start: LocalDate(year: 2025, month: 8, day: 5))
        )

        let occurrences = try await handler.occurrencesBetween(
            from: Self.windowFrom,
            until: Self.windowUntil
        )

        #expect(occurrences.isEmpty)
    }

    /// `CycleReminderHandlerTest.kt:123-130`.
    @Test("occurrence outside the window is filtered out")
    func occurrenceOutsideTheWindowIsFilteredOut() async throws {
        seedRegularPeriods()

        let narrowUntil = Self.windowFrom.addingTimeInterval(24 * 3600)

        let occurrences = try await handler.occurrencesBetween(
            from: Self.windowFrom,
            until: narrowUntil
        )

        #expect(occurrences.isEmpty)
    }

    /// `CycleReminderHandlerTest.kt:132-143`.
    @Test("notification content is suppressed for a stale occurrence key")
    func notificationContentIsSuppressedForAStaleOccurrenceKey() async throws {
        seedRegularPeriods()

        let staleRef = ReminderRef(
            type: .cyclePeriod,
            entityId: CycleReminderHandler.entityId,
            occurrenceKey: "2025-08-20|540"
        )

        #expect(try await handler.notificationContent(for: staleRef) == nil)
    }

    /// `CycleReminderHandlerTest.kt:145-157`.
    @Test("notification content matches the current occurrence")
    func notificationContentMatchesTheCurrentOccurrence() async throws {
        seedRegularPeriods()

        let occurrences = try await handler.occurrencesBetween(
            from: Self.windowFrom,
            until: Self.windowUntil
        )
        let current = try #require(occurrences.first)
        let content = try await handler.notificationContent(
            for: ReminderRef(
                type: .cyclePeriod,
                entityId: current.entityId,
                occurrenceKey: current.occurrenceKey
            )
        )

        let unwrapped = try #require(content)
        #expect(unwrapped.title == "title")
        #expect(unwrapped.text == "body:1")
    }
}
