// Ported 1:1 from `feature/vitals/src/main/kotlin/com/alicansekban/salus/feature/vitals/
// domain/usecase/SaveWeightEntryUseCase.kt`.

import Foundation
import SalusCommon
import SalusModel

/// Validates a weight reading and writes it (`SaveWeightEntryUseCase.kt:12-66`).
///
/// The id comes from an injected `IdGenerator` rather than `UUID()` for `CLAUDE.md`'s reason: an
/// id that cannot be fixed is an assertion that cannot be written.
public struct SaveWeightEntryUseCase: VitalsQuickEntry {
    /// `SaveWeightEntryUseCase.kt:17-21`. Kotlin's `sealed interface` with a `data class` and a
    /// `data object` is an enum with one associated value; both spellings are exhaustive and both
    /// compare by value.
    public enum Result: Equatable, Sendable {
        case saved(WeightEntry)
        case invalidWeight
    }

    /// `SaveWeightEntryUseCase.kt:64` — the lower end of the range a human body weight can fall in.
    public static let minKg = 20.0
    /// `SaveWeightEntryUseCase.kt:65`.
    public static let maxKg = 400.0

    private let repository: any VitalsRepository
    private let idGenerator: any IdGenerator

    public init(repository: any VitalsRepository, idGenerator: any IdGenerator) {
        self.repository = repository
        self.idGenerator = idGenerator
    }

    /// `SaveWeightEntryUseCase.kt:23-42`. Kotlin's `operator fun invoke` is `callAsFunction`, so
    /// the call site reads `useCase(...)` on both platforms.
    ///
    /// - Parameters:
    ///   - existingId: the id of the row being edited, or nil for a new reading.
    ///   - kilograms: optional because the editor hands over whatever the text field parsed to,
    ///     and "not a number yet" is one of the inputs this rejects.
    ///   - note: trimmed, and dropped entirely when nothing but whitespace is left.
    public func callAsFunction(
        existingId: String?,
        kilograms: Double?,
        measuredAt: Date,
        timeZone: TimeZone,
        note: String?
    ) async throws -> Result {
        // `SaveWeightEntryUseCase.kt:30-32`, written as the range the value must be *inside*
        // rather than as the two comparisons it must fail. The two spellings agree on every real
        // number and differ on one value: Kotlin's `kilograms < MIN || kilograms > MAX` is false
        // for NaN, so Android would store a NaN weight, while this rejects it. Both text fields
        // can produce NaN — Swift's `Double("nan")` and Kotlin's `"nan".toDoubleOrNull()` both
        // parse it — so the difference is reachable, and rejecting is the side worth being on.
        guard let kilograms, kilograms >= Self.minKg, kilograms <= Self.maxKg else {
            return .invalidWeight
        }
        let entry = WeightEntry(
            id: existingId ?? idGenerator.newId(),
            measuredAt: measuredAt,
            timeZone: timeZone,
            kilograms: kilograms,
            note: Self.normalisedNote(note)
        )
        try await repository.saveWeightEntry(entry)
        return .saved(entry)
    }

    /// The `VitalsQuickEntry` entry point other features use (`SaveWeightEntryUseCase.kt:48-61`).
    /// It deliberately shares the validation above rather than trusting the caller.
    ///
    /// One port note: Kotlin's `TimeZone.of(timeZoneId)` throws `IllegalTimeZoneException` for an
    /// identifier the platform does not know. Crashing a caller that passed a bad string is not
    /// behaviour worth carrying over, and the contract already has a way to say "nothing was
    /// written" — so an unresolvable identifier is rejected the way an out-of-range weight is.
    public func recordWeight(kilograms: Double, epochMs: Int64, timeZoneId: String) async throws -> Bool {
        guard let timeZone = TimeZone(identifier: timeZoneId) else { return false }
        let result = try await self(
            existingId: nil,
            kilograms: kilograms,
            measuredAt: Date(epochMilliseconds: epochMs),
            timeZone: timeZone,
            note: nil
        )
        if case .saved = result {
            return true
        }
        return false
    }

    /// `SaveWeightEntryUseCase.kt:38` — `note?.trim()?.takeIf { it.isNotEmpty() }`. A note the user
    /// only put spaces in is no note, and storing `"   "` would draw an empty second line under
    /// every such reading.
    private static func normalisedNote(_ note: String?) -> String? {
        guard
            let trimmed = note?.trimmingCharacters(in: .whitespacesAndNewlines),
            !trimmed.isEmpty
        else {
            return nil
        }
        return trimmed
    }
}
