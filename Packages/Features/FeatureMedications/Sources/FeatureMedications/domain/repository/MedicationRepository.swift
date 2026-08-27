// Ported 1:1 from `feature/medications/src/main/kotlin/com/alicansekban/salus/feature/
// medications/domain/repository/MedicationRepository.kt`.
//
// Kotlin's `Flow<T>` becomes `AsyncThrowingStream<T, any Error>` and its `suspend fun` becomes
// `async throws`, the shape `AppointmentsRepository.swift` settled: a database-backed `Flow` lets
// a query failure reach its collector, and a non-throwing stream here would have to swallow it and
// end quietly — an empty screen where Android shows a failure. The `throws` is the port, not an
// addition, and here it also carries the mapper's failures (an unreadable `form`, `recurrence` or
// `status`).
//
// Kotlin's first parameter is named and called by name; Swift's first argument label is dropped
// where the function name already says what the argument is (`saveMedication(_:schedules:)`,
// `upsertLog(_:)`), which is the convention the rest of the tree follows.

/// Read/write access to the current profile's medications, schedules and intake logs
/// (`MedicationRepository.kt:9-45`).
public protocol MedicationRepository: Sendable {
    /// `MedicationRepository.kt:11`.
    func observeActiveMedications() -> AsyncThrowingStream<[MedicationWithSchedules], any Error>

    /// `MedicationRepository.kt:13`.
    func getMedication(id: String) async throws -> MedicationWithSchedules?

    /// Emits nil once the medication is gone, so the detail screen can close itself
    /// (`MedicationRepository.kt:16`).
    func observeMedication(id: String) -> AsyncThrowingStream<MedicationWithSchedules?, any Error>

    /// Saves the medication and its schedule set; schedules absent from `schedules` are
    /// deactivated (never deleted — intake history must survive edits).
    ///
    /// (`MedicationRepository.kt:18-20`.)
    func saveMedication(_ medication: Medication, schedules: [MedicationSchedule]) async throws

    /// `MedicationRepository.kt:22`.
    func deleteMedication(id: String) async throws

    /// `MedicationRepository.kt:24`.
    func getAllActiveMedications() async throws -> [MedicationWithSchedules]

    /// `MedicationRepository.kt:26`.
    func getSchedule(scheduleId: String) async throws -> MedicationSchedule?

    /// `MedicationRepository.kt:28`.
    func getLog(scheduleId: String, epochDay: Int, minuteOfDay: Int) async throws -> IntakeLog?

    /// Insert-or-update keyed by the (schedule, day, minutes) idempotency triple.
    ///
    /// (`MedicationRepository.kt:30-31`.)
    func upsertLog(_ log: IntakeLog) async throws

    /// `MedicationRepository.kt:33`.
    func observeLogsBetween(
        fromEpochDay: Int,
        toEpochDay: Int
    ) -> AsyncThrowingStream<[IntakeLog], any Error>

    /// `MedicationRepository.kt:35`.
    func getLogsBetween(fromEpochDay: Int, toEpochDay: Int) async throws -> [IntakeLog]

    /// Atomic, floors at zero; no-op when stock tracking is off (stock_count NULL).
    ///
    /// (`MedicationRepository.kt:37-38`.)
    func decrementStock(medicationId: String, amount: Double) async throws

    /// The only write path for ``Medication/remindersEnabled``. ``saveMedication(_:schedules:)``
    /// preserves the stored value on purpose, so a stale editor form cannot undo a toggle made
    /// here.
    ///
    /// (`MedicationRepository.kt:40-44`.)
    func setRemindersEnabled(medicationId: String, enabled: Bool) async throws
}
