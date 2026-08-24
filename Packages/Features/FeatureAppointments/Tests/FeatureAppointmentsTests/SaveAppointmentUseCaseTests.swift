// Ported 1:1 from `feature/appointments/src/test/kotlin/com/alicansekban/salus/feature/
// appointments/domain/usecase/SaveAppointmentUseCaseTest.kt`.
//
// Four cases, in the Kotlin order, with the Kotlin inputs and the Kotlin expectations. Each one
// cites the Kotlin line it comes from, so a change on either side that is not made on the other is
// visible in the diff.

import Foundation
import SalusCommon
import SalusModel
import SalusTesting
import Testing

@testable import FeatureAppointments

@Suite("SaveAppointmentUseCase")
struct SaveAppointmentUseCaseTests {
    /// `SaveAppointmentUseCaseTest.kt:21` — `TimeZone.of("Europe/Istanbul")`.
    private static let zone = FixedSalusClock.defaultZone
    /// `SaveAppointmentUseCaseTest.kt:22` — 1_755_000_000_000 ms.
    private static let now = Date(timeIntervalSince1970: 1_755_000_000)

    private let repository: FakeAppointmentsRepository
    private let useCase: SaveAppointmentUseCase

    init() {
        // `SaveAppointmentUseCaseTest.kt:23-26`.
        let repository = FakeAppointmentsRepository(zone: Self.zone)
        self.repository = repository
        useCase = SaveAppointmentUseCase(
            repository: repository,
            idGenerator: FixedIdGenerator(id: "generated-id"),
            clock: FixedSalusClock(now: Self.now, timeZone: Self.zone)
        )
    }

    /// `SaveAppointmentUseCaseTest.kt:28-42` — the title is checked before the date and the time,
    /// so a form with neither reports the title first.
    @Test("blank title is rejected")
    func blankTitleIsRejected() async throws {
        let result = try await useCase(
            existingId: nil,
            title: "   ",
            doctorName: nil,
            location: nil,
            notes: nil,
            dateEpochDay: 20700,
            minuteOfDay: 630,
            reminderOffsetsMinutes: []
        )

        #expect(result == .missingTitle)
        #expect(repository.current().isEmpty)
    }

    /// `SaveAppointmentUseCaseTest.kt:44-56` — either half missing rejects the whole.
    @Test("missing date or time is rejected")
    func missingDateOrTimeIsRejected() async throws {
        let noDate = try await useCase(
            existingId: nil,
            title: "Checkup",
            doctorName: nil,
            location: nil,
            notes: nil,
            dateEpochDay: nil,
            minuteOfDay: 630,
            reminderOffsetsMinutes: []
        )
        let noTime = try await useCase(
            existingId: nil,
            title: "Checkup",
            doctorName: nil,
            location: nil,
            notes: nil,
            dateEpochDay: 20700,
            minuteOfDay: nil,
            reminderOffsetsMinutes: []
        )

        #expect(noDate == .missingDateTime)
        #expect(noTime == .missingDateTime)
        #expect(repository.current().isEmpty)
    }

    /// `SaveAppointmentUseCaseTest.kt:58-84`.
    @Test("new appointment gets generated id and normalized fields")
    func newAppointmentGetsGeneratedIdAndNormalizedFields() async throws {
        let result = try await useCase(
            existingId: nil,
            title: "  Dental checkup  ",
            doctorName: "  ",
            location: " Clinic A ",
            notes: "",
            dateEpochDay: 20700,
            minuteOfDay: 630,
            reminderOffsetsMinutes: [1440, 60, 1440, -5]
        )

        let saved = try #require(Self.savedAppointment(result))
        #expect(saved.id == "generated-id")
        #expect(saved.title == "Dental checkup")
        #expect(saved.doctorName == nil)
        #expect(saved.location == "Clinic A")
        #expect(saved.notes == nil)
        #expect(saved.startsAt == LocalDateTime(isoLocalString: "2026-09-04T10:30"))
        #expect(saved.timeZone == Self.zone)
        #expect(saved.status == .scheduled)
        #expect(saved.durationMinutes == Appointment.defaultDurationMinutes)
        // Negative offsets dropped, duplicates removed, ascending order.
        #expect(saved.reminderOffsetsMinutes == [60, 1440])
        #expect(repository.current() == [saved])
    }

    /// `SaveAppointmentUseCaseTest.kt:86-124` — the three fields the editor cannot touch come back
    /// off the existing row, never off the input.
    @Test("update preserves id duration status and specialty")
    func updatePreservesIdDurationStatusAndSpecialty() async throws {
        let existing = Appointment(
            id: "a1",
            title: "Old title",
            doctorName: "Dr. Old",
            specialty: "Cardiology",
            location: nil,
            notes: nil,
            startsAt: LocalDateTime(date: LocalDate(year: 2026, month: 9, day: 4), minuteOfDay: 630),
            timeZone: Self.zone,
            durationMinutes: 45,
            status: .scheduled,
            reminderOffsetsMinutes: [60]
        )
        repository.setAppointments(existing)

        let result = try await useCase(
            existingId: "a1",
            title: "New title",
            doctorName: "Dr. New",
            location: nil,
            notes: nil,
            dateEpochDay: 20701,
            minuteOfDay: 540,
            reminderOffsetsMinutes: [10080]
        )

        let saved = try #require(Self.savedAppointment(result))
        #expect(saved.id == "a1")
        #expect(saved.title == "New title")
        #expect(saved.specialty == "Cardiology")
        #expect(saved.durationMinutes == 45)
        #expect(saved.status == .scheduled)
        #expect(saved.startsAt == LocalDateTime(isoLocalString: "2026-09-05T09:00"))
        #expect(saved.reminderOffsetsMinutes == [10080])
        #expect(repository.current().count == 1)
    }

    /// Kotlin's `(result as Result.Saved).appointment`, without the cast that crashes on the other
    /// two cases.
    private static func savedAppointment(_ result: SaveAppointmentUseCase.Result) -> Appointment? {
        guard case let .saved(appointment) = result else { return nil }
        return appointment
    }
}

/// The twin of Kotlin's SAM-converted `IdGenerator { "generated-id" }`
/// (`SaveAppointmentUseCaseTest.kt:25`): every id the use case asks for is the same fixed string,
/// so the assertion on it is an assertion and not a guess. A duplicate of `FeatureVitals`' test
/// helper of the same name — features never depend on each other, and this lives in a test target.
struct FixedIdGenerator: IdGenerator {
    let id: String

    func newId() -> String {
        id
    }
}
