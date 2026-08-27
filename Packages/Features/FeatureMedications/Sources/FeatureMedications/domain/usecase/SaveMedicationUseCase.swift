// Ported 1:1 from `feature/medications/src/main/kotlin/com/alicansekban/salus/feature/
// medications/domain/usecase/SaveMedicationUseCase.kt`.

import Foundation
import SalusModel
import SalusReminder

/// Validates a medication form and writes it with its schedule set
/// (`SaveMedicationUseCase.kt:9-45`).
public struct SaveMedicationUseCase: Sendable {
    /// `SaveMedicationUseCase.kt:14-21`. Kotlin's `sealed interface` of six `data object`s is an
    /// enum with no associated values; both spellings are exhaustive and both compare by value.
    ///
    /// `Sendable` is the one addition: Kotlin's `data object`s are trivially shareable, and a
    /// public Swift enum gets no implicit conformance, so a caller that hops isolation between
    /// awaiting this and reading the result would not compile without it.
    public enum Result: Equatable, Sendable {
        case success
        case emptyName
        case noDoseTimes
        case invalidInterval
        case noDaysSelected
        case endBeforeStart
    }

    private let repository: any MedicationRepository
    private let reminderScheduler: any ReminderScheduler

    public init(repository: any MedicationRepository, reminderScheduler: any ReminderScheduler) {
        self.repository = repository
        self.reminderScheduler = reminderScheduler
    }

    /// `SaveMedicationUseCase.kt:23-45`. Kotlin's `operator fun invoke` is `callAsFunction`, so the
    /// call site reads `useCase(...)` on both platforms.
    ///
    /// The order is the Kotlin one and is load-bearing: a form with every field wrong reports the
    /// *name* first, then the dates, then the schedules, so the editor highlights one field at a
    /// time in the order the form reads. Within the schedules, the first offending schedule
    /// decides — Kotlin returns out of the `forEach`.
    public func callAsFunction(
        _ medication: Medication,
        schedules: [MedicationSchedule]
    ) async throws -> Result {
        // `SaveMedicationUseCase.kt:24` — `isBlank()`, so the *untrimmed* name is what is judged
        // and a name of nothing but spaces is no name.
        let trimmedName = medication.name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedName.isEmpty {
            return .emptyName
        }
        // `SaveMedicationUseCase.kt:25-26` — an open-ended course (no end date) is always valid.
        if let end = medication.endDateEpochDay, end < medication.startDateEpochDay {
            return .endBeforeStart
        }

        // `SaveMedicationUseCase.kt:28-29` — a medication with no dose time would never produce an
        // occurrence, so it would be saved and then never seen again.
        let activeSchedules = schedules.filter(\.isActive)
        if activeSchedules.isEmpty {
            return .noDoseTimes
        }
        // `SaveMedicationUseCase.kt:30-38`. `DAILY` and `AS_NEEDED` carry no extra field to get
        // wrong; the `switch` is exhaustive so a fifth recurrence cannot be added without a
        // decision here.
        for schedule in activeSchedules {
            switch schedule.recurrence {
            case .intervalDays:
                if (schedule.intervalDays ?? 0) < 1 {
                    return .invalidInterval
                }

            case .daysOfWeek:
                if schedule.daysOfWeekMask == 0 {
                    return .noDaysSelected
                }

            case .asNeeded, .daily:
                break
            }
        }

        // `SaveMedicationUseCase.kt:40` — the name is stored trimmed, so the list and every
        // reminder title read the same as what the user meant to type.
        try await repository.saveMedication(medication.with(name: trimmedName), schedules: schedules)
        // Keep OS alarms in sync with the new schedule set (no orphan alarms).
        // (`SaveMedicationUseCase.kt:41-42`.)
        reminderScheduler.requestSync()
        return .success
    }
}

extension Medication {
    /// The twin of Kotlin's `data class` `copy(name = ...)` (`SaveMedicationUseCase.kt:40`). Swift
    /// has no synthesised `copy`, and a memberwise call at the call site would bury the one field
    /// that changes under eleven that do not.
    fileprivate func with(name: String) -> Medication {
        Medication(
            id: id,
            name: name,
            form: form,
            strengthValue: strengthValue,
            strengthUnit: strengthUnit,
            instructions: instructions,
            stockCount: stockCount,
            stockThreshold: stockThreshold,
            startDateEpochDay: startDateEpochDay,
            endDateEpochDay: endDateEpochDay,
            isActive: isActive,
            remindersEnabled: remindersEnabled
        )
    }
}
