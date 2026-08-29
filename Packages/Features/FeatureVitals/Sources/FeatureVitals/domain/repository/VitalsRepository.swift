// Ported from `feature/vitals/src/main/kotlin/com/alicansekban/salus/feature/vitals/
// domain/repository/VitalsRepository.kt`.
//
// All thirteen Kotlin members, spelled identically: five for weight (`VitalsRepository.kt:13-21`),
// four for blood pressure (`:23-29`) and four for glucose (`:31-37`).
//
// **The asymmetry is Android's and is copied on purpose.** Only weight has an `observeLatest…`;
// blood pressure and glucose have none, because their "latest" is the first row of the window the
// list screen already collects. Adding one here would be a query Android does not run and a second
// source of truth for the same number.
//
// Kotlin's `Flow<T>` becomes `AsyncThrowingStream<T, any Error>` and its `suspend fun` becomes
// `async throws` for the reason `ProfileRepository.swift` spells out: a Room-backed `Flow` lets a
// query failure reach its collector, and a non-throwing stream here would have to swallow it and
// end quietly — an empty screen where Android shows a failure. The `throws` is the port, not an
// addition.

import Foundation

/// Read/write access to the vitals measurements of the current profile
/// (`VitalsRepository.kt:11-38`).
public protocol VitalsRepository: Sendable {
    /// Every weight reading inside a window that is **closed at both ends**, oldest first
    /// (`VitalsRepository.kt:13`). The window is the DAO's `BETWEEN`, which includes both bounds.
    func observeWeightHistory(from: Date, until: Date) -> AsyncThrowingStream<[WeightEntry], any Error>

    /// The newest weight reading, or nil before there is one (`VitalsRepository.kt:15`).
    func observeLatestWeight() -> AsyncThrowingStream<WeightEntry?, any Error>

    /// One reading by id, or nil when no *weight* row carries that id
    /// (`VitalsRepository.kt:17`).
    func getWeightEntry(id: String) async throws -> WeightEntry?

    /// Inserts or updates the reading, by id (`VitalsRepository.kt:19`).
    func saveWeightEntry(_ entry: WeightEntry) async throws

    /// `VitalsRepository.kt:21`.
    func deleteWeightEntry(id: String) async throws

    /// Every blood-pressure reading inside a window that is **closed at both ends**, oldest first
    /// (`VitalsRepository.kt:23`).
    func observeBloodPressureHistory(
        from: Date,
        until: Date
    ) -> AsyncThrowingStream<[BloodPressureEntry], any Error>

    /// One reading by id, or nil when no *blood-pressure* row carries that id
    /// (`VitalsRepository.kt:25`).
    func getBloodPressureEntry(id: String) async throws -> BloodPressureEntry?

    /// Inserts or updates the reading, by id (`VitalsRepository.kt:27`).
    func saveBloodPressureEntry(_ entry: BloodPressureEntry) async throws

    /// `VitalsRepository.kt:29`.
    func deleteBloodPressureEntry(id: String) async throws

    /// Every glucose reading inside a window that is **closed at both ends**, oldest first
    /// (`VitalsRepository.kt:31`). The values are the canonical mg/dL ones; converting to the
    /// user's unit is the reader's job.
    func observeGlucoseHistory(from: Date, until: Date) -> AsyncThrowingStream<[GlucoseEntry], any Error>

    /// One reading by id, or nil when no *glucose* row carries that id (`VitalsRepository.kt:33`).
    func getGlucoseEntry(id: String) async throws -> GlucoseEntry?

    /// Inserts or updates the reading, by id (`VitalsRepository.kt:35`).
    func saveGlucoseEntry(_ entry: GlucoseEntry) async throws

    /// `VitalsRepository.kt:37`.
    func deleteGlucoseEntry(id: String) async throws
}
