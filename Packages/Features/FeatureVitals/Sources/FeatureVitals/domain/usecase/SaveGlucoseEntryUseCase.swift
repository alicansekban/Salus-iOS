// Ported 1:1 from `feature/vitals/src/main/kotlin/com/alicansekban/salus/feature/vitals/
// domain/usecase/SaveGlucoseEntryUseCase.kt`.

import Foundation
import SalusCommon
import SalusModel

/// Accepts the value in the unit the user typed it in; persists canonically in mg/dL
/// (`SaveGlucoseEntryUseCase.kt:15-55`).
///
/// It deliberately does **not** conform to `VitalsQuickEntry`: only weight does on Android too.
public struct SaveGlucoseEntryUseCase {
    /// `SaveGlucoseEntryUseCase.kt:20-24`.
    public enum Result: Equatable, Sendable {
        case saved(GlucoseEntry)
        case invalidValue
    }

    /// `SaveGlucoseEntryUseCase.kt:52` — the bounds are on the **canonical mg/dL** value, which is
    /// why the conversion runs first.
    public static let minMgDl = 20.0
    /// `SaveGlucoseEntryUseCase.kt:53`.
    public static let maxMgDl = 600.0

    private let repository: any VitalsRepository
    private let idGenerator: any IdGenerator

    public init(repository: any VitalsRepository, idGenerator: any IdGenerator) {
        self.repository = repository
        self.idGenerator = idGenerator
    }

    // The seven parameters are the Kotlin signature (`SaveGlucoseEntryUseCase.kt:26-34`), which is
    // the editor form's fields one for one — `SaveBloodPressureEntryUseCase`'s note.
    // swiftlint:disable function_parameter_count

    /// `SaveGlucoseEntryUseCase.kt:26-49`.
    ///
    /// **Convert first, then range-check.** A reading typed in mmol/L is judged against the same
    /// 20…600 mg/dL bounds as one typed in mg/dL (≙ 1.1099…33.2996 mmol/L), so the unit the user
    /// happens to read in never changes which readings the app accepts.
    ///
    /// - Parameters:
    ///   - existingId: the id of the row being edited, or nil for a new reading.
    ///   - value: optional because the editor hands over whatever the text field parsed to, and
    ///     "not a number yet" is one of the inputs this rejects.
    ///   - unit: the unit `value` is *in*; it is not stored, only used to convert.
    ///   - note: trimmed, and dropped entirely when nothing but whitespace is left.
    public func callAsFunction(
        existingId: String?,
        value: Double?,
        unit: GlucoseUnit,
        measuredAt: Date,
        timeZone: TimeZone,
        measurementContext: MeasurementContext?,
        note: String?
    ) async throws -> Result {
        // `SaveGlucoseEntryUseCase.kt:35-38`, written as the range the value must be *inside*
        // rather than as the two comparisons it must fail — the NaN divergence
        // `SaveBloodPressureEntryUseCase` spells out, applied here too (ruling 5). NaN survives
        // the conversion in either unit, so the guard is what stops it.
        guard let value else {
            return .invalidValue
        }
        let mgDl = GlucoseConversion.toMgDl(value, unit: unit)
        guard mgDl >= Self.minMgDl, mgDl <= Self.maxMgDl else {
            return .invalidValue
        }
        let entry = GlucoseEntry(
            id: existingId ?? idGenerator.newId(),
            measuredAt: measuredAt,
            timeZone: timeZone,
            mgDl: mgDl,
            measurementContext: measurementContext,
            note: normalisedNote(note)
        )
        try await repository.saveGlucoseEntry(entry)
        return .saved(entry)
    }

    // swiftlint:enable function_parameter_count

    /// `SaveGlucoseEntryUseCase.kt:45` — `note?.trim()?.takeIf { it.isNotEmpty() }`, the same
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
