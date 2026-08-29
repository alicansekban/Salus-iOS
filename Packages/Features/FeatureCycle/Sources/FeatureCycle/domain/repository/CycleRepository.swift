// Ported 1:1 from Android
// `feature/cycle/src/main/kotlin/com/alicansekban/salus/feature/cycle/domain/repository/CycleRepository.kt`.
//
// Kotlin's `Flow<T>` becomes `AsyncThrowingStream<T, any Error>` and its `suspend fun` becomes
// `async throws`, the shape `MedicationRepository.swift` and `AppointmentsRepository.swift`
// settled: a database-backed `Flow` lets a query failure reach its collector, and a non-throwing
// stream here would have to swallow it and end quietly — an empty screen where Android shows a
// failure. The `throws` is the port, not an addition; it also carries the mapper's failures (an
// unreadable `flow` or `mood` raw value).
//
// Kotlin's first parameter is named and called by name; Swift's first argument label is dropped
// where the function name already says what the argument is (`savePeriod(_:)`, `saveDayLog(_:)`,
// `getPeriodStartingOn(_:)`), which is the convention the rest of the tree follows.

import SalusModel

/// Read/write access to the current profile's recorded periods, symptom catalog and day logs
/// (`CycleRepository.kt:9-27`).
public protocol CycleRepository: Sendable {
    /// `CycleRepository.kt:11`.
    func observePeriods() -> AsyncThrowingStream<[CyclePeriod], any Error>

    /// The period that has no end date yet, if one is running (`CycleRepository.kt:13`).
    func getOpenPeriod() async throws -> CyclePeriod?

    /// `CycleRepository.kt:15`.
    func getPeriodStartingOn(_ date: LocalDate) async throws -> CyclePeriod?

    /// `CycleRepository.kt:17`.
    func savePeriod(_ period: CyclePeriod) async throws

    /// `CycleRepository.kt:19`.
    func deletePeriod(id: String) async throws

    /// Emits the symptom catalog; seeds the starter catalog on first collection if empty
    /// (`CycleRepository.kt:21-22`).
    func observeSymptoms() -> AsyncThrowingStream<[Symptom], any Error>

    /// `CycleRepository.kt:24`.
    func getDayLog(on date: LocalDate) async throws -> CycleDayLog?

    /// `CycleRepository.kt:26`.
    func saveDayLog(_ log: CycleDayLog) async throws
}
