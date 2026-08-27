// Ported 1:1 from `feature/medications/src/test/kotlin/com/alicansekban/salus/feature/
// medications/domain/usecase/SaveMedicationUseCaseTest.kt`.
//
// Six cases, in the Kotlin order, with the Kotlin inputs and the Kotlin expectations. Each one
// cites the Kotlin line it comes from, so a change on either side that is not made on the other is
// visible in the diff.

import SalusModel
import Testing

@testable import FeatureMedications

@Suite("SaveMedicationUseCase")
struct SaveMedicationUseCaseTests {
    // `SaveMedicationUseCaseTest.kt:15-17`.
    private let repository = FakeMedicationRepository()
    private let scheduler = FakeReminderScheduler()
    private let useCase: SaveMedicationUseCase

    init() {
        useCase = SaveMedicationUseCase(repository: repository, reminderScheduler: scheduler)
    }

    /// `SaveMedicationUseCaseTest.kt:19-27`.
    @Test("valid medication saves and requests a reminder sync")
    func validMedicationSavesAndRequestsAReminderSync() async throws {
        let result = try await useCase(testMedication(), schedules: [testSchedule()])

        #expect(result == .success)
        #expect(repository.medications.count == 1)
        #expect(scheduler.syncRequests == 1)
    }

    /// `SaveMedicationUseCaseTest.kt:29-36` — nothing is written and no sync is asked for, so a
    /// rejected form cannot leave the alarm set behind.
    @Test("blank name is rejected")
    func blankNameIsRejected() async throws {
        let result = try await useCase(testMedication(name: "   "), schedules: [testSchedule()])

        #expect(result == .emptyName)
        #expect(repository.medications.isEmpty)
        #expect(scheduler.syncRequests == 0)
    }

    /// `SaveMedicationUseCaseTest.kt:38-43` — an inactive schedule is not a dose time.
    @Test("no active dose times is rejected")
    func noActiveDoseTimesIsRejected() async throws {
        let result = try await useCase(testMedication(), schedules: [testSchedule(isActive: false)])

        #expect(result == .noDoseTimes)
    }

    /// `SaveMedicationUseCaseTest.kt:45-53`.
    @Test("interval below one is rejected")
    func intervalBelowOneIsRejected() async throws {
        let result = try await useCase(
            testMedication(),
            schedules: [testSchedule(recurrence: .intervalDays, intervalDays: 0)]
        )

        #expect(result == .invalidInterval)
    }

    /// `SaveMedicationUseCaseTest.kt:55-63`.
    @Test("days-of-week without any day is rejected")
    func daysOfWeekWithoutAnyDayIsRejected() async throws {
        let result = try await useCase(
            testMedication(),
            schedules: [testSchedule(recurrence: .daysOfWeek, daysOfWeekMask: 0)]
        )

        #expect(result == .noDaysSelected)
    }

    /// `SaveMedicationUseCaseTest.kt:65-73`.
    @Test("end date before start date is rejected")
    func endDateBeforeStartDateIsRejected() async throws {
        let result = try await useCase(
            testMedication(startDateEpochDay: 100, endDateEpochDay: 99),
            schedules: [testSchedule()]
        )

        #expect(result == .endBeforeStart)
    }

    /// No Kotlin twin: `medication.copy(name = medication.name.trim())`
    /// (`SaveMedicationUseCase.kt:41`) is asserted nowhere on Android, and a trim that silently
    /// stopped happening would leave `" Aspirin "` in the list and in every reminder title.
    @Test("the saved name is trimmed")
    func theSavedNameIsTrimmed() async throws {
        let result = try await useCase(testMedication(name: "  Aspirin  "), schedules: [testSchedule()])

        #expect(result == .success)
        #expect(repository.medications.first?.medication.name == "Aspirin")
    }
}
