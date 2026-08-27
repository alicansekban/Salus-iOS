// Ported 1:1 from `feature/medications/src/main/kotlin/com/alicansekban/salus/feature/
// medications/domain/usecase/SnoozeDoseUseCase.kt`.

import Foundation
import SalusCommon
import SalusModel
import SalusReminder

/// Snoozes a dose by 10 minutes: persists snoozed_until on the occurrence's log and asks the
/// reminder engine to re-sync — the handler then re-emits the occurrence with the snooze
/// instant as its trigger, which reschedules the same ledger row. Survives process death.
///
/// (`SnoozeDoseUseCase.kt:12-14`.)
public struct SnoozeDoseUseCase: Sendable {
    /// Ten minutes, as seconds (`SnoozeDoseUseCase.kt:51`). Kotlin's `10.minutes` is a
    /// `kotlin.time.Duration`; the Swift twin of a duration in this tree is `TimeInterval`, and
    /// the column it feeds is milliseconds either way.
    public static let snoozeDuration: TimeInterval = 600

    private let repository: any MedicationRepository
    private let clock: any SalusClock
    private let idGenerator: any IdGenerator
    private let reminderScheduler: any ReminderScheduler

    public init(
        repository: any MedicationRepository,
        clock: any SalusClock,
        idGenerator: any IdGenerator,
        reminderScheduler: any ReminderScheduler
    ) {
        self.repository = repository
        self.clock = clock
        self.idGenerator = idGenerator
        self.reminderScheduler = reminderScheduler
    }

    /// `SnoozeDoseUseCase.kt:23-48`.
    public func callAsFunction(scheduleId: String, epochDay: Int, minuteOfDay: Int) async throws {
        let existing = try await repository.getLog(
            scheduleId: scheduleId,
            epochDay: epochDay,
            minuteOfDay: minuteOfDay
        )
        // `SnoozeDoseUseCase.kt:25` — a dose the user has already answered for is not re-armed, so
        // a stale notification action cannot bring back an alarm that is done with.
        if existing?.status == .taken || existing?.status == .skipped {
            return
        }

        // `SnoozeDoseUseCase.kt:27` — same reason as marking taken: no orphan logs.
        guard let schedule = try await repository.getSchedule(scheduleId: scheduleId) else { return }
        // `SnoozeDoseUseCase.kt:28` — `(clock.now() + SNOOZE_DURATION).toEpochMilliseconds()`.
        let snoozedUntil = clock.nowEpochMilliseconds() + Int64(Self.snoozeDuration) * 1000
        let base = existing ?? IntakeLog(
            id: idGenerator.newId(),
            scheduleId: scheduleId,
            medicationId: schedule.medicationId,
            epochDay: epochDay,
            minuteOfDay: minuteOfDay,
            status: .pending,
            takenAtEpochMs: nil,
            snoozedUntilEpochMs: nil,
            doseAmount: schedule.doseAmount,
            note: nil
        )
        // `SnoozeDoseUseCase.kt:42-45` — the status stays PENDING: a snoozed dose is still owed.
        let log = base.snoozed(untilEpochMs: snoozedUntil)
        try await repository.upsertLog(log)
        // The re-sync is what turns the stored instant into a rescheduled alarm
        // (`SnoozeDoseUseCase.kt:47`).
        reminderScheduler.requestSync()
    }
}

extension IntakeLog {
    /// The twin of Kotlin's `data class` `copy(status = PENDING, snoozedUntilEpochMs = …)`
    /// (`SnoozeDoseUseCase.kt:42-45`). Swift has no synthesised `copy`, and a memberwise call at
    /// the call site would bury the two fields that change under eight that do not.
    fileprivate func snoozed(untilEpochMs: Int64) -> IntakeLog {
        IntakeLog(
            id: id,
            scheduleId: scheduleId,
            medicationId: medicationId,
            epochDay: epochDay,
            minuteOfDay: minuteOfDay,
            status: .pending,
            takenAtEpochMs: takenAtEpochMs,
            snoozedUntilEpochMs: untilEpochMs,
            doseAmount: doseAmount,
            note: note
        )
    }
}
