// Ported 1:1 from `feature/appointments/src/main/kotlin/com/alicansekban/salus/feature/
// appointments/domain/usecase/SaveAppointmentUseCase.kt`.

import Foundation
import SalusCommon
import SalusModel

/// Validates an appointment form and writes it (`SaveAppointmentUseCase.kt:13-63`).
///
/// The id comes from an injected `IdGenerator` and the zone from an injected `SalusClock`, for
/// `CLAUDE.md`'s reason: a value that cannot be fixed is an assertion that cannot be written.
public struct SaveAppointmentUseCase: Sendable {
    /// `SaveAppointmentUseCase.kt:19-25`. Kotlin's `sealed interface` with one `data class` and two
    /// `data object`s is an enum with one associated value; both spellings are exhaustive and both
    /// compare by value.
    public enum Result: Equatable, Sendable {
        case saved(Appointment)
        case missingTitle
        case missingDateTime
    }

    private let repository: any AppointmentsRepository
    private let idGenerator: any IdGenerator
    private let clock: any SalusClock

    public init(repository: any AppointmentsRepository, idGenerator: any IdGenerator, clock: any SalusClock) {
        self.repository = repository
        self.idGenerator = idGenerator
        self.clock = clock
    }

    // The eight parameters are the Kotlin signature (`SaveAppointmentUseCase.kt:27-36`), which is
    // the editor form's fields one for one. Grouping them into a request struct would be a second
    // shape for the same data and would put the port a refactor away from its twin, so the rule is
    // waived here rather than the signature bent.
    // swiftlint:disable function_parameter_count

    /// `SaveAppointmentUseCase.kt:27-62`. Kotlin's `operator fun invoke` is `callAsFunction`, so
    /// the call site reads `useCase(...)` on both platforms.
    ///
    /// The evaluation order is the Kotlin one and is load-bearing: a form with neither a title nor
    /// a date reports the *title*, so the editor highlights one field at a time in the order the
    /// form reads.
    ///
    /// - Parameters:
    ///   - existingId: the id of the appointment being edited, or nil for a new one.
    ///   - dateEpochDay: optional because the editor hands over whatever the date field holds, and
    ///     "nothing picked yet" is one of the inputs this rejects. Same for `minuteOfDay`.
    ///   - reminderOffsetsMinutes: minutes before the start; negatives dropped, duplicates removed,
    ///     ascending. No upper bound and no maximum count, exactly as Kotlin has none.
    public func callAsFunction(
        existingId: String?,
        title: String,
        doctorName: String?,
        location: String?,
        notes: String?,
        dateEpochDay: Int?,
        minuteOfDay: Int?,
        reminderOffsetsMinutes: [Int]
    ) async throws -> Result {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedTitle.isEmpty {
            return .missingTitle
        }
        guard let dateEpochDay, let minuteOfDay else { return .missingDateTime }

        // The three fields the editor cannot touch — `specialty`, `durationMinutes`, `status` —
        // come off the stored row, so saving an edited form never silently rewrites them.
        var existing: Appointment?
        if let existingId {
            existing = try await repository.getAppointment(id: existingId)
        }
        let appointment = Appointment(
            id: existingId ?? idGenerator.newId(),
            title: trimmedTitle,
            doctorName: Self.normalised(doctorName),
            specialty: existing?.specialty,
            location: Self.normalised(location),
            notes: Self.normalised(notes),
            // `LocalDateTime(LocalDate.fromEpochDays(d), LocalTime(m / 60, m % 60))`
            // (`SaveAppointmentUseCase.kt:49-52`). The hour/minute split has no twin here:
            // `SalusModel.LocalDateTime` stores the minute of day the editor already produces, so
            // dividing it out and multiplying it back would only add a rounding surface.
            startsAt: LocalDateTime(date: LocalDate(epochDay: dateEpochDay), minuteOfDay: minuteOfDay),
            timeZone: clock.timeZone(),
            durationMinutes: existing?.durationMinutes ?? Appointment.defaultDurationMinutes,
            status: existing?.status ?? .scheduled,
            reminderOffsetsMinutes: Self.normalisedOffsets(reminderOffsetsMinutes)
        )
        try await repository.saveAppointment(appointment)
        return .saved(appointment)
    }

    // swiftlint:enable function_parameter_count

    /// `SaveAppointmentUseCase.kt:45`, `:47`, `:48` — `x?.trim()?.takeIf { it.isNotEmpty() }`. A
    /// field the user only put spaces in is no field, and storing `"   "` would draw an empty line
    /// under every such appointment.
    private static func normalised(_ text: String?) -> String? {
        guard
            let trimmed = text?.trimmingCharacters(in: .whitespacesAndNewlines),
            !trimmed.isEmpty
        else {
            return nil
        }
        return trimmed
    }

    /// `SaveAppointmentUseCase.kt:57` — `filter { it >= 0 }.distinct().sorted()`. Sorting after
    /// de-duplicating is what makes the stored offsets ascending, which is the order the domain
    /// model promises.
    private static func normalisedOffsets(_ offsets: [Int]) -> [Int] {
        var seen = Set<Int>()
        return offsets
            .filter { $0 >= 0 && seen.insert($0).inserted }
            .sorted()
    }
}
