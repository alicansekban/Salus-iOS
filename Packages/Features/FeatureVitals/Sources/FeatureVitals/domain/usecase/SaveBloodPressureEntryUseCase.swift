// Ported 1:1 from `feature/vitals/src/main/kotlin/com/alicansekban/salus/feature/vitals/
// domain/usecase/SaveBloodPressureEntryUseCase.kt`.

import Foundation
import SalusCommon

/// Validates a blood-pressure reading and writes it
/// (`SaveBloodPressureEntryUseCase.kt:11-70`).
///
/// It deliberately does **not** conform to `VitalsQuickEntry`: only weight does on Android too, so
/// nothing outside this feature can record a reading without the editor's two fields.
public struct SaveBloodPressureEntryUseCase: Sendable {
    /// `SaveBloodPressureEntryUseCase.kt:16-26`. Kotlin's `sealed interface` with one `data class`
    /// and four `data object`s is an enum with one associated value; both spellings are exhaustive
    /// and both compare by value.
    public enum Result: Equatable, Sendable {
        case saved(BloodPressureEntry)
        case invalidSystolic
        case invalidDiastolic
        case invalidPulse
        case systolicNotAboveDiastolic
    }

    /// `SaveBloodPressureEntryUseCase.kt:63`.
    public static let minSystolic = 60.0
    /// `SaveBloodPressureEntryUseCase.kt:64`.
    public static let maxSystolic = 250.0
    /// `SaveBloodPressureEntryUseCase.kt:65`.
    public static let minDiastolic = 30.0
    /// `SaveBloodPressureEntryUseCase.kt:66`.
    public static let maxDiastolic = 150.0
    /// `SaveBloodPressureEntryUseCase.kt:67`.
    public static let minPulse = 20.0
    /// `SaveBloodPressureEntryUseCase.kt:68`.
    public static let maxPulse = 250.0

    private let repository: any VitalsRepository
    private let idGenerator: any IdGenerator

    public init(repository: any VitalsRepository, idGenerator: any IdGenerator) {
        self.repository = repository
        self.idGenerator = idGenerator
    }

    // The seven parameters are the Kotlin signature (`SaveBloodPressureEntryUseCase.kt:28-36`),
    // which is the editor form's fields one for one. Grouping them into a request struct would be
    // a second shape for the same data and would put the port a refactor away from its twin, so
    // the rule is waived here rather than the signature bent — `SaveAppointmentUseCase`'s note.
    // swiftlint:disable function_parameter_count

    /// `SaveBloodPressureEntryUseCase.kt:28-60`. Kotlin's `operator fun invoke` is
    /// `callAsFunction`, so the call site reads `useCase(...)` on both platforms.
    ///
    /// **The evaluation order is the Kotlin one and is load-bearing**: systolic, then diastolic,
    /// then a pulse only if one was typed, then the two against each other. A form with two bad
    /// fields reports the first, so the editor highlights one field at a time in the order the
    /// form reads.
    ///
    /// - Parameters:
    ///   - existingId: the id of the row being edited, or nil for a new reading.
    ///   - systolic: optional because the editor hands over whatever the text field parsed to, and
    ///     "not a number yet" is one of the inputs this rejects. Same for `diastolic`.
    ///   - pulse: optional in a second sense too — a cuff that does not measure it is a normal
    ///     cuff, so `nil` is a valid reading and only a *present* pulse is range-checked.
    ///   - note: trimmed, and dropped entirely when nothing but whitespace is left.
    public func callAsFunction(
        existingId: String?,
        systolic: Double?,
        diastolic: Double?,
        pulse: Double?,
        measuredAt: Date,
        timeZone: TimeZone,
        note: String?
    ) async throws -> Result {
        // `SaveBloodPressureEntryUseCase.kt:37-39`, `:40-42` and `:43-45`, each written as the
        // range the value must be *inside* rather than as the two comparisons it must fail. The
        // two spellings agree on every real number and differ on one value: Kotlin's
        // `systolic < MIN || systolic > MAX` is false for NaN, so Android stores a NaN reading
        // where this rejects it. Both text fields can produce NaN — `Double("nan")` parses on
        // both platforms — so the difference is reachable.
        //
        // This is the **recorded divergence** `SaveWeightEntryUseCase` already carries (§11 A11),
        // applied to the two new use cases by iOS-M7 ruling 5. `NaN is rejected` in
        // `SaveBloodPressureEntryUseCaseTests` pins it until Android catches up.
        guard let systolic, systolic >= Self.minSystolic, systolic <= Self.maxSystolic else {
            return .invalidSystolic
        }
        guard let diastolic, diastolic >= Self.minDiastolic, diastolic <= Self.maxDiastolic else {
            return .invalidDiastolic
        }
        if let pulse, !(pulse >= Self.minPulse && pulse <= Self.maxPulse) {
            return .invalidPulse
        }
        // `SaveBloodPressureEntryUseCase.kt:46-48` — strictly above, so an equal pair is rejected.
        guard systolic > diastolic else {
            return .systolicNotAboveDiastolic
        }
        let entry = BloodPressureEntry(
            id: existingId ?? idGenerator.newId(),
            measuredAt: measuredAt,
            timeZone: timeZone,
            systolic: systolic,
            diastolic: diastolic,
            pulse: pulse,
            note: normalisedNote(note)
        )
        try await repository.saveBloodPressureEntry(entry)
        return .saved(entry)
    }

    // swiftlint:enable function_parameter_count

    /// `SaveBloodPressureEntryUseCase.kt:56` — `note?.trim()?.takeIf { it.isNotEmpty() }`, the same
    /// normalisation `SaveWeightEntryUseCase` applies. A note the user only put spaces in is no
    /// note, and storing `"   "` would draw an empty second line under every such reading.
    private func normalisedNote(_ note: String?) -> String? {
        guard
            let trimmed = note?.trimmingCharacters(in: .whitespacesAndNewlines),
            !trimmed.isEmpty
        else {
            return nil
        }
        return trimmed
    }
}
