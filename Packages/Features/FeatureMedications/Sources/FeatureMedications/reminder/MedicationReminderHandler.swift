// Ported 1:1 from `feature/medications/src/main/kotlin/com/alicansekban/salus/feature/
// medications/reminder/MedicationReminderHandler.kt`.
//
// Kotlin's `suspend fun` becomes `async throws`: the repository this reads is database-backed on
// both platforms, and the iOS port carries the query failure to the caller rather than swallowing
// it (`MedicationRepository.swift` spells out why). A `class` becomes a `struct` — the type holds
// five injected references and no state of its own, which is what `ReminderHandler: Sendable`
// wants anyway. Kotlin's `Context` parameter is gone: the five `getString` calls it existed for
// travel in as `MedicationNotificationTexts`.

import Foundation
import SalusCommon
import SalusModel
import SalusReminder

/// Feeds medication dose occurrences to the reminder engine and reacts to the notification's
/// Taken/Snooze actions. Dose times carry LOCAL-time semantics: every sync re-converts
/// (epochDay, minuteOfDay) with the CURRENT time zone, so a tz/DST change simply produces new
/// trigger instants and the engine reschedules the same ledger rows.
///
/// (`MedicationReminderHandler.kt:28-33`.)
public struct MedicationReminderHandler: ReminderHandler {
    /// `MedicationReminderHandler.kt:127`.
    public static let actionTaken = "taken"
    /// `MedicationReminderHandler.kt:128`.
    public static let actionSnooze = "snooze"

    public let type: ReminderType = .medicationDose

    private let repository: any MedicationRepository
    private let markDoseTaken: MarkDoseTakenUseCase
    private let snoozeDose: SnoozeDoseUseCase
    private let clock: any SalusClock
    private let texts: any MedicationNotificationTexts

    public init(
        repository: any MedicationRepository,
        markDoseTaken: MarkDoseTakenUseCase,
        snoozeDose: SnoozeDoseUseCase,
        clock: any SalusClock,
        texts: any MedicationNotificationTexts
    ) {
        self.repository = repository
        self.markDoseTaken = markDoseTaken
        self.snoozeDose = snoozeDose
        self.clock = clock
        self.texts = texts
    }

    /// `MedicationReminderHandler.kt:45-78`.
    public func occurrencesBetween(from: Date, until: Date) async throws -> [ReminderOccurrence] {
        let zone = clock.timeZone()
        let fromDay = from.wallClock(in: zone).date.epochDay
        let untilDay = until.wallClock(in: zone).date.epochDay

        // Silenced medications contribute nothing here, so the window sync drops their
        // pending alarms exactly as a delete does. They stay active everywhere else.
        let medications = try await repository.getAllActiveMedications()
            .filter(\.medication.remindersEnabled)
        if medications.isEmpty {
            return []
        }
        let occurrences = DoseOccurrenceGenerator.occurrencesFor(
            medications: medications,
            fromEpochDay: fromDay,
            toEpochDay: untilDay
        )
        // Kotlin's `associateBy`, whose `Triple` key is spelled out as a type here. It keeps the
        // LAST entry when two rows share a key, which is what `uniquingKeysWith` repeats; the
        // (schedule, day, minutes) triple is the ledger's idempotency key, so no two ever do.
        let logs = try await repository.getLogsBetween(fromEpochDay: fromDay, toEpochDay: untilDay)
        let logsByKey = Dictionary(
            logs.map { (LogKey(scheduleId: $0.scheduleId, epochDay: $0.epochDay, minuteOfDay: $0.minuteOfDay), $0) },
            uniquingKeysWith: { _, last in last }
        )

        return occurrences.compactMap { occurrence in
            let log = logsByKey[
                LogKey(
                    scheduleId: occurrence.scheduleId,
                    epochDay: occurrence.epochDay,
                    minuteOfDay: occurrence.minuteOfDay
                )
            ]
            // Doses the user already resolved don't ring again.
            if log?.status == .taken || log?.status == .skipped {
                return nil
            }
            let trigger = log?.snoozedUntilEpochMs.map { Date(epochMilliseconds: $0) }
                ?? LocalDateTime(
                    date: LocalDate(epochDay: occurrence.epochDay),
                    minuteOfDay: occurrence.minuteOfDay
                ).instant(in: zone)
            // The generator works on whole days; trim to the engine's exact instant window.
            if trigger < from || trigger >= until {
                return nil
            }
            return ReminderOccurrence(
                entityId: occurrence.scheduleId,
                occurrenceKey: DoseOccurrenceKey.encode(
                    epochDay: occurrence.epochDay,
                    minuteOfDay: occurrence.minuteOfDay
                ),
                triggerAt: trigger
            )
        }
    }

    /// `MedicationReminderHandler.kt:80-116`.
    ///
    /// A reminder is materialized ahead of time and fires later, by which point the schedule or
    /// the medication may have been deleted, deactivated or silenced, or the dose may already have
    /// been recorded — each of which means there is nothing worth saying, so the content is nil and
    /// the engine drops the notification.
    public func notificationContent(for ref: ReminderRef) async throws -> ReminderNotificationContent? {
        guard let occurrence = DoseOccurrenceKey.decode(ref.occurrenceKey) else { return nil }
        guard let schedule = try await repository.getSchedule(scheduleId: ref.entityId) else { return nil }
        guard let medication = try await repository.getMedication(id: schedule.medicationId)?.medication
        else {
            return nil
        }
        if !medication.isActive || !medication.remindersEnabled {
            return nil
        }
        let log = try await repository.getLog(
            scheduleId: ref.entityId,
            epochDay: occurrence.epochDay,
            minuteOfDay: occurrence.minuteOfDay
        )
        if log?.status == .taken || log?.status == .skipped {
            return nil
        }

        // Kotlin's `listOfNotNull(...).joinToString(" ")`, over the same two nullable columns.
        let strength = [medication.strengthValue.map(formatAmount), medication.strengthUnit]
            .compactMap(\.self)
            .joined(separator: " ")
        let title = texts.doseTitle(medicationName: medication.name)
        // Kotlin's `isBlank()` reads `Char.isWhitespace()`, so the Swift set is
        // `.whitespacesAndNewlines` — a strength unit of spaces alone must not print as " ".
        let text = strength.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? texts.doseTextPlain(amount: formatAmount(schedule.doseAmount))
            : texts.doseText(amount: formatAmount(schedule.doseAmount), strength: strength)
        return ReminderNotificationContent(
            title: title,
            text: text,
            // The order is load-bearing on iOS in a way it is not on Android: AlarmKit's alert
            // surface shows the FIRST declared action as its only secondary button, so recording
            // the dose is the one-tap answer and snooze is the one behind the notification.
            actions: [
                ReminderAction(id: Self.actionTaken, label: texts.actionTaken),
                ReminderAction(id: Self.actionSnooze, label: texts.actionSnooze)
            ],
            // A missed dose is a health event, not an FYI: it rings like a clock alarm rather
            // than sliding past as a heads-up. A snoozed dose comes back through this exact
            // path — snooze re-triggers THIS occurrence (see ``occurrencesBetween(from:until:)``)
            // instead of materializing a reminder of its own — so it rings again, as it must.
            presentation: .alarm
        )
    }

    /// `MedicationReminderHandler.kt:118-124`.
    ///
    /// Kotlin's `when` has no `else`, so every other action id — ``ReminderActionIds/dismiss``
    /// included — falls through untouched. That is the behaviour, not an omission: dismiss
    /// silences the alarm without answering for the dose, and the occurrence stays owed.
    public func onAction(ref: ReminderRef, actionId: String) async throws {
        guard let occurrence = DoseOccurrenceKey.decode(ref.occurrenceKey) else { return }
        switch actionId {
        case Self.actionTaken:
            try await markDoseTaken.markTaken(
                scheduleId: ref.entityId,
                epochDay: occurrence.epochDay,
                minuteOfDay: occurrence.minuteOfDay
            )

        case Self.actionSnooze:
            try await snoozeDose(
                scheduleId: ref.entityId,
                epochDay: occurrence.epochDay,
                minuteOfDay: occurrence.minuteOfDay
            )

        default:
            break
        }
    }
}

/// Kotlin's `Triple(scheduleId, epochDay, minuteOfDay)` (`MedicationReminderHandler.kt:57, 60`).
/// Swift tuples are not `Hashable`, so the ledger's idempotency triple is a named type — which
/// also stops the three fields being read in the wrong order at a lookup site.
private struct LogKey: Hashable {
    let scheduleId: String
    let epochDay: Int
    let minuteOfDay: Int
}
