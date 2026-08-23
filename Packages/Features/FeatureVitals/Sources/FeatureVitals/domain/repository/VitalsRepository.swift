// Ported from `feature/vitals/src/main/kotlin/com/alicansekban/salus/feature/vitals/
// domain/repository/VitalsRepository.kt`.
//
// Weight only. The Kotlin interface declares thirteen members — five for weight
// (`VitalsRepository.kt:13-21`), four for blood pressure and four for glucose; the other eight
// arrive with iOS-M7, under the Kotlin names, in this file. The five below are the Kotlin five,
// spelled identically.
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
}
