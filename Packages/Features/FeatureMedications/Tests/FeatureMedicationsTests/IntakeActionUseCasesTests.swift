// Ported 1:1 from `feature/medications/src/test/kotlin/com/alicansekban/salus/feature/
// medications/domain/usecase/IntakeActionUseCasesTest.kt`.
//
// Six cases, in the Kotlin order, with the Kotlin inputs and the Kotlin expectations. The two use
// cases are tested together because every case here is about how they meet: idempotence, and what
// one leaves behind for the other.

import Foundation
import SalusModel
import SalusTesting
import Testing

@testable import FeatureMedications

@Suite("Intake action use cases")
struct IntakeActionUseCasesTests {
    /// `IntakeActionUseCasesTest.kt:22` — `Instant.fromEpochMilliseconds(1_760_000_000_000)`.
    private static let nowEpochMs: Int64 = 1_760_000_000_000
    private static let now = Date(timeIntervalSince1970: 1_760_000_000)

    private let repository = FakeMedicationRepository()
    private let scheduler = FakeReminderScheduler()
    private let markTaken: MarkDoseTakenUseCase
    private let snooze: SnoozeDoseUseCase

    init() {
        // `IntakeActionUseCasesTest.kt:23-27` — one medication, one schedule, two units a dose.
        repository.setMedications([
            MedicationWithSchedules(
                medication: testMedication(),
                schedules: [testSchedule(doseAmount: 2.0)]
            )
        ])
        // `IntakeActionUseCasesTest.kt:29-30`.
        let clock = FixedSalusClock(now: Self.now)
        let idGenerator = FixedIdGenerator(id: "generated-id")
        // `IntakeActionUseCasesTest.kt:32-33`.
        markTaken = MarkDoseTakenUseCase(
            repository: repository,
            clock: clock,
            idGenerator: idGenerator
        )
        snooze = SnoozeDoseUseCase(
            repository: repository,
            clock: clock,
            idGenerator: idGenerator,
            reminderScheduler: scheduler
        )
    }

    /// `IntakeActionUseCasesTest.kt:36-44`.
    @Test("taken creates a TAKEN log and decrements stock by the dose amount")
    func takenCreatesATakenLogAndDecrementsStockByTheDoseAmount() async throws {
        try await markTaken(scheduleId: "sch-1", epochDay: 100, minuteOfDay: 480)

        let log = try #require(repository.logs.first)
        #expect(repository.logs.count == 1)
        #expect(log.status == .taken)
        #expect(log.takenAtEpochMs == Self.nowEpochMs)
        #expect(log.snoozedUntilEpochMs == nil)
        #expect(repository.stockDecrements == [StockDecrement(medicationId: "med-1", amount: 2.0)])
    }

    /// `IntakeActionUseCasesTest.kt:47-53` — the second call reads a TAKEN log and returns before
    /// it can decrement stock a second time.
    @Test("taken is idempotent - no double stock decrement")
    func takenIsIdempotentNoDoubleStockDecrement() async throws {
        try await markTaken(scheduleId: "sch-1", epochDay: 100, minuteOfDay: 480)
        try await markTaken(scheduleId: "sch-1", epochDay: 100, minuteOfDay: 480)

        #expect(repository.logs.count == 1)
        #expect(repository.stockDecrements.count == 1)
    }

    /// `IntakeActionUseCasesTest.kt:56-66`.
    @Test("snooze stores snoozed_until ten minutes ahead and requests a sync")
    func snoozeStoresSnoozedUntilTenMinutesAheadAndRequestsASync() async throws {
        try await snooze(scheduleId: "sch-1", epochDay: 100, minuteOfDay: 480)

        let log = try #require(repository.logs.first)
        #expect(repository.logs.count == 1)
        #expect(log.status == .pending)
        // Kotlin reads `SNOOZE_DURATION.inWholeMilliseconds` here
        // (`IntakeActionUseCasesTest.kt:61-64`); the literal is what makes "ten minutes" an
        // assertion rather than a restatement of the constant under test.
        #expect(SnoozeDoseUseCase.snoozeDuration == 600)
        #expect(log.snoozedUntilEpochMs == Self.nowEpochMs + 600_000)
        #expect(scheduler.syncRequests == 1)
    }

    /// `IntakeActionUseCasesTest.kt:69-75` — a dose already recorded is not re-armed, so a stale
    /// notification action cannot resurrect an alarm the user is done with.
    @Test("snooze after taken is a no-op")
    func snoozeAfterTakenIsANoOp() async throws {
        try await markTaken(scheduleId: "sch-1", epochDay: 100, minuteOfDay: 480)
        try await snooze(scheduleId: "sch-1", epochDay: 100, minuteOfDay: 480)

        let log = try #require(repository.logs.first)
        #expect(repository.logs.count == 1)
        #expect(log.status == .taken)
        #expect(scheduler.syncRequests == 0)
    }

    /// `IntakeActionUseCasesTest.kt:78-85` — the snooze instant is cleared, so the re-emitted
    /// occurrence stops being scheduled once the dose is recorded.
    @Test("taken after snooze clears the snooze and marks taken")
    func takenAfterSnoozeClearsTheSnoozeAndMarksTaken() async throws {
        try await snooze(scheduleId: "sch-1", epochDay: 100, minuteOfDay: 480)
        try await markTaken(scheduleId: "sch-1", epochDay: 100, minuteOfDay: 480)

        let log = try #require(repository.logs.first)
        #expect(repository.logs.count == 1)
        #expect(log.status == .taken)
        #expect(log.snoozedUntilEpochMs == nil)
    }

    /// `IntakeActionUseCasesTest.kt:88-93` — both actions run from a notification whose schedule
    /// may have been deleted meanwhile; neither writes an orphan log.
    @Test("unknown schedule is ignored")
    func unknownScheduleIsIgnored() async throws {
        try await markTaken(scheduleId: "missing", epochDay: 100, minuteOfDay: 480)
        try await snooze(scheduleId: "missing", epochDay: 100, minuteOfDay: 480)

        #expect(repository.logs.isEmpty)
    }
}
