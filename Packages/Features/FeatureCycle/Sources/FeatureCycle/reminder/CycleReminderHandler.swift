// Ported 1:1 from `feature/cycle/src/main/kotlin/com/alicansekban/salus/feature/cycle/reminder/
// CycleReminderHandler.kt`.
//
// Kotlin's `class` becomes a `struct`: the type holds five injected references and no state of
// its own, which is what `ReminderHandler: Sendable` wants anyway — the shape
// `MedicationReminderHandler` settled. Kotlin's `Context` has no twin; the three `getString`
// calls it existed for travel in as ``CycleNotificationTexts``.
//
// Kotlin reads the first value of two flows with `.first()`. Swift's `AsyncSequence` has no such
// operator in the standard library, so each read is a `for await` that returns on the first
// element — the same "take one value and stop collecting" semantics, with the one difference
// Kotlin does not have to spell: `.first()` throws on a flow that completes empty, while the
// helpers below answer `nil` and the handler then emits nothing. A stream that ends without a
// value describes no configuration and no recorded periods, which is exactly the "nothing to
// remind about" case.
//
// Kotlin's `"$reminderDate|$minuteOfDay"` interpolates `LocalDate.toString()`, i.e. ISO-8601
// `yyyy-MM-dd`. The Swift twin formats the three `LocalDate` fields directly rather than going
// through a `DateFormatter`, which would drag in a locale, a calendar and a time zone to print a
// key that has none of the three.

import Foundation
import SalusCommon
import SalusModel
import SalusReminder

/// Feeds the single period-start reminder to the engine (`CycleReminderHandler.kt:33-88`).
///
/// The occurrence is DERIVED at sync time from the current prediction — predictions are never
/// persisted (the M6 rule). Nothing is emitted while the reminder is off or the prediction's
/// confidence is `.low`, and a stale fired alarm re-checks the same conditions in
/// ``notificationContent(for:)`` and suppresses itself.
public struct CycleReminderHandler: ReminderHandler {
    /// There is only ever one pending period reminder (`CycleReminderHandler.kt:84-87`).
    public static let entityId = "cycle-period"

    public let type: ReminderType = .cyclePeriod

    private let repository: any CycleRepository
    private let predictor: CyclePredictor
    private let settings: any CycleReminderSettings
    private let clock: any SalusClock
    private let texts: any CycleNotificationTexts

    public init(
        repository: any CycleRepository,
        predictor: CyclePredictor,
        settings: any CycleReminderSettings,
        clock: any SalusClock,
        texts: any CycleNotificationTexts
    ) {
        self.repository = repository
        self.predictor = predictor
        self.settings = settings
        self.clock = clock
        self.texts = texts
    }

    /// `CycleReminderHandler.kt:50-51`.
    ///
    /// There is no past-trigger guard, on either platform: the engine's window starts at "now",
    /// so a trigger behind it is filtered by `from` alone.
    public func occurrencesBetween(from: Date, until: Date) async throws -> [ReminderOccurrence] {
        guard let occurrence = try await currentOccurrence(),
              occurrence.triggerAt >= from, occurrence.triggerAt < until
        else {
            return []
        }
        return [occurrence]
    }

    /// `CycleReminderHandler.kt:53-63`.
    ///
    /// Re-derives: if the prediction moved, the toggle flipped, or confidence dropped since
    /// scheduling, the fired alarm is stale and must stay silent.
    public func notificationContent(for ref: ReminderRef) async throws -> ReminderNotificationContent? {
        guard let occurrence = try await currentOccurrence() else { return nil }
        guard occurrence.occurrenceKey == ref.occurrenceKey else { return nil }
        guard let config = await currentConfig() else { return nil }
        return ReminderNotificationContent(
            title: texts.title(),
            text: texts.body(leadDays: config.leadDays)
        )
    }

    /// `CycleReminderHandler.kt:65-82`.
    private func currentOccurrence() async throws -> ReminderOccurrence? {
        guard let config = await currentConfig(), config.enabled else { return nil }

        guard let periods = try await currentPeriods(),
              let prediction = predictor(periods, today: clock.today()),
              prediction.confidence != .low
        else {
            return nil
        }

        let reminderDate = prediction.nextPeriodStart.minusDays(config.leadDays)
        return ReminderOccurrence(
            entityId: Self.entityId,
            occurrenceKey: Self.occurrenceKey(on: reminderDate, minuteOfDay: config.minuteOfDay),
            // Local-time semantics: resolved with the CURRENT zone at call time (DST-safe;
            // zone/DST changes trigger a window re-sync upstream).
            triggerAt: clock.instant(of: reminderDate, minuteOfDay: config.minuteOfDay)
        )
    }

    /// Kotlin's `"$reminderDate|$minuteOfDay"` (`CycleReminderHandler.kt:77`) — the ISO day and
    /// the minute of it, which is all the identity one daily reminder needs.
    static func occurrenceKey(on date: LocalDate, minuteOfDay: Int) -> String {
        String(format: "%04d-%02d-%02d|%d", date.year, date.month, date.day, minuteOfDay)
    }

    /// Kotlin's `settings.config.first()` (`CycleReminderHandler.kt:58, 66`).
    private func currentConfig() async -> CycleReminderConfig? {
        for await config in settings.config {
            return config
        }
        return nil
    }

    /// Kotlin's `repository.observePeriods().first()` (`CycleReminderHandler.kt:69`).
    private func currentPeriods() async throws -> [CyclePeriod]? {
        for try await periods in repository.observePeriods() {
            return periods
        }
        return nil
    }
}
