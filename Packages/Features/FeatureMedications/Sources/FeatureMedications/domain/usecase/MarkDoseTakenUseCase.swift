// Ported 1:1 from `feature/medications/src/main/kotlin/com/alicansekban/salus/feature/
// medications/domain/usecase/MarkDoseTakenUseCase.kt`.

import SalusCommon
import SalusModel

/// Marks one dose occurrence TAKEN and decrements stock. Idempotent: a second call for the
/// same occurrence is a no-op (no double stock decrement). Also runs from the notification
/// action receiver with the app closed.
///
/// (`MarkDoseTakenUseCase.kt:11-13`. The Kotlin doc says "receiver"; on iOS the same code runs
/// from the notification-response handler, which has the same "app not on screen" constraint.)
public struct MarkDoseTakenUseCase: DoseActions {
    private let repository: any MedicationRepository
    private let clock: any SalusClock
    private let idGenerator: any IdGenerator

    public init(
        repository: any MedicationRepository,
        clock: any SalusClock,
        idGenerator: any IdGenerator
    ) {
        self.repository = repository
        self.clock = clock
        self.idGenerator = idGenerator
    }

    /// The ``SalusModel/DoseActions`` conformance, which is how other features reach this write
    /// path without importing this one (`MarkDoseTakenUseCase.kt:21-23`).
    public func markTaken(scheduleId: String, epochDay: Int, minuteOfDay: Int) async throws {
        try await callAsFunction(scheduleId: scheduleId, epochDay: epochDay, minuteOfDay: minuteOfDay)
    }

    /// `MarkDoseTakenUseCase.kt:25-50`.
    public func callAsFunction(scheduleId: String, epochDay: Int, minuteOfDay: Int) async throws {
        let existing = try await repository.getLog(
            scheduleId: scheduleId,
            epochDay: epochDay,
            minuteOfDay: minuteOfDay
        )
        // `MarkDoseTakenUseCase.kt:27` — the idempotence guard. A notification action fired twice,
        // or fired again from a stale notification, must not take a second unit off the stock.
        if existing?.status == .taken {
            return
        }

        // `MarkDoseTakenUseCase.kt:29` — the schedule may have been deleted between the alarm
        // being scheduled and the user acting on it; an orphan log would belong to nothing.
        guard let schedule = try await repository.getSchedule(scheduleId: scheduleId) else { return }
        let base = existing ?? IntakeLog(
            id: idGenerator.newId(),
            scheduleId: scheduleId,
            medicationId: schedule.medicationId,
            epochDay: epochDay,
            minuteOfDay: minuteOfDay,
            status: .pending,
            takenAtEpochMs: nil,
            snoozedUntilEpochMs: nil,
            // The dose comes off the schedule, not off the caller: the amount recorded is the
            // amount that was due (`MarkDoseTakenUseCase.kt:40`).
            doseAmount: schedule.doseAmount,
            note: nil
        )
        // `MarkDoseTakenUseCase.kt:43-47` — recording the dose clears any snooze on it, so the
        // occurrence stops being rescheduled.
        let log = base.markedTaken(atEpochMs: clock.nowEpochMilliseconds())
        try await repository.upsertLog(log)
        // `MarkDoseTakenUseCase.kt:49` — `log.doseAmount`, not `schedule.doseAmount`: an existing
        // log carries what was due when it was written, and the schedule may have changed since.
        try await repository.decrementStock(medicationId: schedule.medicationId, amount: log.doseAmount)
    }
}

extension IntakeLog {
    /// The twin of Kotlin's `data class` `copy(status = TAKEN, takenAtEpochMs = …,
    /// snoozedUntilEpochMs = null)` (`MarkDoseTakenUseCase.kt:43-47`). Swift has no synthesised
    /// `copy`, and a memberwise call at the call site would bury the three fields that change
    /// under seven that do not.
    fileprivate func markedTaken(atEpochMs: Int64) -> IntakeLog {
        IntakeLog(
            id: id,
            scheduleId: scheduleId,
            medicationId: medicationId,
            epochDay: epochDay,
            minuteOfDay: minuteOfDay,
            status: .taken,
            takenAtEpochMs: atEpochMs,
            snoozedUntilEpochMs: nil,
            doseAmount: doseAmount,
            note: note
        )
    }
}
