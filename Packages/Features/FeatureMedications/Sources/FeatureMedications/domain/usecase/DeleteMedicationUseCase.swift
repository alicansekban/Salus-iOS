// Ported 1:1 from `feature/medications/src/main/kotlin/com/alicansekban/salus/feature/
// medications/domain/usecase/DeleteMedicationUseCase.kt`.

import SalusReminder

/// Deletes a medication and re-syncs the alarm window (`DeleteMedicationUseCase.kt:6-14`).
///
/// The sync is not optional bookkeeping: the deleted medication's occurrences are still on the
/// OS's schedule until the next sync drops them, which is how a deleted medication would still
/// ring.
public struct DeleteMedicationUseCase: Sendable {
    private let repository: any MedicationRepository
    private let reminderScheduler: any ReminderScheduler

    public init(repository: any MedicationRepository, reminderScheduler: any ReminderScheduler) {
        self.repository = repository
        self.reminderScheduler = reminderScheduler
    }

    /// `DeleteMedicationUseCase.kt:10-13`. Kotlin names the parameter `medicationId`; Swift's
    /// label is `id:`, matching ``MedicationRepository/deleteMedication(id:)`` and the rest of the
    /// tree — the type name already says what is being deleted.
    public func callAsFunction(id: String) async throws {
        try await repository.deleteMedication(id: id)
        reminderScheduler.requestSync()
    }
}
