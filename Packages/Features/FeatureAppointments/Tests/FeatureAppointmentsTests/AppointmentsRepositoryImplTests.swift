// Covers `data/AppointmentsRepositoryImpl.swift`, the port of
// `feature/appointments/src/test/kotlin/com/alicansekban/salus/feature/appointments/data/
// AppointmentsRepositoryImplTest.kt`.
//
// The Kotlin test backs the repository with a hand-written `FakeAppointmentDao`. This one uses the
// **real** `AppointmentDao` over `SalusDatabase.inMemory`, which is the template's RepositoryImpl
// standard and the shape `VitalsRepositoryImplTests` set: the facts worth proving here — that a
// save is a *replace* of the reminder rows, that deleting an appointment cascades to them, that
// the two observations are joined against the profile's reminder rows — are facts about real SQL
// and a real transaction, and a fake DAO would only prove the fake.
//
// The four Kotlin cases come first, by name. Three iOS-only cases follow for the observations:
// Kotlin gets its combine from `kotlinx.coroutines`, iOS has to write one (`LatestOfBoth.swift`),
// and new code without a test is how a stream that never emits ships.
//
// Deterministic by construction: a `FixedSalusClock`, rows seeded before the observation starts,
// and every emission read by awaiting the stream rather than by sleeping.

import Foundation
import SalusCommon
import SalusDatabase
import SalusModel
import SalusReminder
import SalusTesting
import Testing

@testable import FeatureAppointments

/// The twin of the Kotlin test's `RecordingReminderScheduler` (`AppointmentsRepositoryImplTest.kt:88-95`).
/// `@unchecked Sendable` for `FixedSalusClock`'s reason: the counter is mutable state and the lock
/// is what makes the promise true.
final class RecordingReminderScheduler: ReminderScheduler, @unchecked Sendable {
    private let lock = NSLock()
    private var requests = 0

    var syncRequests: Int {
        lock.withLock { requests }
    }

    func requestSync() {
        lock.withLock { requests += 1 }
    }
}

@Suite("AppointmentsRepositoryImpl")
struct AppointmentsRepositoryImplTests {
    /// `AppointmentsRepositoryImplTest.kt:100` — 1_755_000_000_000 ms.
    private static let now = Date(timeIntervalSince1970: 1_755_000_000)
    private static let zone = FixedSalusClock.defaultZone

    /// `AppointmentsRepositoryImplTest.kt:105-116`.
    private static let appointment = Appointment(
        id: "a1",
        title: "Checkup",
        doctorName: "Dr. X",
        specialty: nil,
        location: nil,
        notes: nil,
        startsAt: LocalDateTime(date: LocalDate(year: 2026, month: 9, day: 1), minuteOfDay: 10 * 60 + 30),
        timeZone: zone,
        durationMinutes: 60,
        status: .scheduled,
        reminderOffsetsMinutes: [60, 1440]
    )

    /// `AppointmentsRepositoryImplTest.kt:118-126`.
    @Test("save persists appointment with reminder rows and requests a sync")
    func savePersistsAppointmentWithReminderRowsAndRequestsASync() async throws {
        let fixture = try Self.makeFixture()

        try await fixture.repository.saveAppointment(Self.appointment)

        #expect(fixture.scheduler.syncRequests == 1)
        #expect(try await fixture.repository.getAppointment(id: "a1") == Self.appointment)
        #expect(try await fixture.dao.getRemindersFor(appointmentId: "a1").count == 2)
    }

    /// `AppointmentsRepositoryImplTest.kt:128-140` — the save is a replace, and `created_at`
    /// survives it while `updated_at` moves. The `updated_at` assertion has no Kotlin twin; it
    /// pins the other half of the same statement.
    @Test("saving again replaces reminder rows and keeps createdAt")
    func savingAgainReplacesReminderRowsAndKeepsCreatedAt() async throws {
        let fixture = try Self.makeFixture()
        try await fixture.repository.saveAppointment(Self.appointment)
        let createdAt = try #require(try await fixture.dao.getById("a1")).createdAtEpochMs

        let later = Self.now.addingTimeInterval(3600)
        fixture.clock.advanceTo(later)
        try await fixture.repository.saveAppointment(Self.appointment.with(reminderOffsetsMinutes: [10080]))

        #expect(fixture.scheduler.syncRequests == 2)
        let stored = try #require(try await fixture.dao.getById("a1"))
        #expect(stored.createdAtEpochMs == createdAt)
        #expect(stored.updatedAtEpochMs == later.epochMilliseconds)
        let reminders = try await fixture.dao.getRemindersFor(appointmentId: "a1")
        #expect(reminders.map(\.offsetMinutes) == [10080])
    }

    /// `AppointmentsRepositoryImplTest.kt:142-152` — the reminder rows go with the appointment
    /// because of the foreign key's `ON DELETE CASCADE`, which is a fact about the real schema.
    @Test("delete removes appointment with its reminders and requests a sync")
    func deleteRemovesAppointmentWithItsRemindersAndRequestsASync() async throws {
        let fixture = try Self.makeFixture()
        try await fixture.repository.saveAppointment(Self.appointment)

        try await fixture.repository.deleteAppointment(id: "a1")

        #expect(fixture.scheduler.syncRequests == 2)
        #expect(try await fixture.dao.getById("a1") == nil)
        #expect(try await fixture.dao.getRemindersFor(appointmentId: "a1").isEmpty)
        #expect(try await fixture.repository.getAppointment(id: "a1") == nil)
    }

    /// `AppointmentsRepositoryImplTest.kt:154-166` — one batched reminder fetch for every
    /// scheduled appointment, and an appointment with no offsets still comes back.
    @Test("getScheduledAppointments joins reminder offsets per appointment")
    func getScheduledAppointmentsJoinsReminderOffsetsPerAppointment() async throws {
        let fixture = try Self.makeFixture()
        try await fixture.repository.saveAppointment(Self.appointment)
        try await fixture.repository.saveAppointment(
            Self.appointment.with(id: "a2", reminderOffsetsMinutes: [])
        )

        let scheduled = try await fixture.repository.getScheduledAppointments().sorted { $0.id < $1.id }

        #expect(scheduled.map(\.id) == ["a1", "a2"])
        #expect(scheduled.first?.reminderOffsetsMinutes == [60, 1440])
        #expect(scheduled.last?.reminderOffsetsMinutes.isEmpty == true)
    }

    /// iOS-only: the `combine` half of `withReminders` (`AppointmentsRepositoryImpl.kt:67-73`).
    /// Soonest first, each appointment carrying only its own offsets — the profile-wide reminder
    /// stream is grouped by `appointmentId`, so a mis-grouping would hand one appointment another's
    /// reminders.
    @Test("observeUpcoming emits scheduled appointments soonest first, each with its own offsets")
    func observeUpcomingEmitsScheduledAppointmentsSoonestFirst() async throws {
        let fixture = try Self.makeFixture()
        try await fixture.repository.saveAppointment(Self.appointment)
        try await fixture.repository.saveAppointment(
            Self.appointment.with(id: "a0", startsAt: Self.startsAt(2026, 8, 31), reminderOffsetsMinutes: [10080])
        )
        try await fixture.repository.saveAppointment(
            Self.appointment.with(id: "cancelled", status: .cancelled)
        )

        var iterator = fixture.repository.observeUpcoming(from: Self.now).makeAsyncIterator()
        let upcoming = try #require(try await iterator.next())

        #expect(upcoming.map(\.id) == ["a0", "a1"])
        #expect(upcoming.first?.reminderOffsetsMinutes == [10080])
        #expect(upcoming.last?.reminderOffsetsMinutes == [60, 1440])
    }

    /// iOS-only, the other half of the same partition (`AppointmentsRepositoryImpl.kt:28-29`):
    /// newest first, and a non-`SCHEDULED` appointment is past however far ahead it starts.
    @Test("observePast emits started and non-scheduled appointments, newest first")
    func observePastEmitsStartedAndNonScheduledAppointmentsNewestFirst() async throws {
        let fixture = try Self.makeFixture()
        let past = Self.appointment.with(id: "past", startsAt: Self.startsAt(2025, 1, 8))
        try await fixture.repository.saveAppointment(past)
        try await fixture.repository.saveAppointment(Self.appointment)
        try await fixture.repository.saveAppointment(Self.appointment.with(id: "cancelled", status: .cancelled))

        var iterator = fixture.repository.observePast(before: Self.now).makeAsyncIterator()
        let history = try #require(try await iterator.next())

        #expect(history.map(\.id) == ["cancelled", "past"])
        #expect(history.first?.reminderOffsetsMinutes == [60, 1440])
    }

    /// iOS-only: `AppointmentsRepositoryImpl.kt:31-35`. The nil emission is what closes the detail
    /// screen when the appointment it is showing is deleted, so it is the one emission that must
    /// not be swallowed.
    @Test(
        "observeAppointment emits the appointment with its offsets, then nil once it is gone",
        .timeLimit(.minutes(1))
    )
    func observeAppointmentEmitsTheAppointmentThenNilOnceItIsGone() async throws {
        let fixture = try Self.makeFixture()
        try await fixture.repository.saveAppointment(Self.appointment)

        var iterator = fixture.repository.observeAppointment(id: "a1").makeAsyncIterator()
        let first = try #require(try await iterator.next())
        #expect(first == Self.appointment)

        try await fixture.repository.deleteAppointment(id: "a1")

        // Bounded rather than "drain until nil": a regression that stops emitting the deletion has
        // to fail the assertion, not hang the suite. Two emissions is the most the delete can
        // produce (one per observation), and the `.timeLimit` above catches a stream that stalls
        // instead of emitting at all.
        var latest = first
        for _ in 0 ..< 2 {
            guard let emitted = try await iterator.next() else { break }
            latest = emitted
            if emitted == nil {
                break
            }
        }
        #expect(latest == nil)
    }

    /// iOS-only, and the regression companion to `LatestOfBothTests`\'
    /// `a slow transform never overwrites a fresher pair`, on the real path that made the ordering
    /// bug reachable: `upsertWithReminders` commits the appointment and its reminder rows in one
    /// transaction, so every save wakes `observeUpcoming` and `observeRemindersForProfile` at once
    /// and `latestOfBoth` has two source emissions to order. Before the fix the value the consumer
    /// settled on could be the pair carrying the *previous* offsets.
    ///
    /// The sleep is deliberate and is the thing under test: the assertion is about which emission is
    /// the last one, and there is nothing to await for "no further emission is coming". Ten rounds
    /// with alternating offsets, so a stale settle cannot pass by matching what was already there.
    ///
    /// Measured, so nobody has to guess: with the ordering fix reverted this case still *passes* —
    /// the real `transform` is a record→domain mapping and is too fast to lose the race reliably.
    /// The discriminating test is `LatestOfBothTests.a slow transform never overwrites a fresher
    /// pair`, which forces the interleaving with a delay hook and fails all ten of its rounds. This
    /// case is the end-to-end companion: it pins that a save settles on its own offsets over the
    /// real DAO, real SQL and the real transaction that wakes both observations at once.
    @Test("saving while observing settles on the new reminder offsets", .timeLimit(.minutes(1)))
    func savingWhileObservingSettlesOnTheNewReminderOffsets() async throws {
        let fixture = try Self.makeFixture()
        try await fixture.repository.saveAppointment(Self.appointment)

        var iterator = fixture.repository.observeUpcoming(from: Self.now).makeAsyncIterator()
        let initial = try #require(try await iterator.next())
        #expect(initial.first?.reminderOffsetsMinutes == [60, 1440])

        for round in 0 ..< 10 {
            let offsets = round.isMultiple(of: 2) ? [10080] : [60]
            try await fixture.repository.saveAppointment(
                Self.appointment.with(reminderOffsetsMinutes: offsets)
            )
            // Long enough for every emission this commit triggers to have been written into the
            // `bufferingNewest(1)` buffer, so what is read below is what settled.
            try await Task.sleep(nanoseconds: 100_000_000)

            let settled = try #require(try await iterator.next())
            #expect(settled.first?.reminderOffsetsMinutes == offsets)
        }
    }

    private static func startsAt(_ year: Int, _ month: Int, _ day: Int) -> LocalDateTime {
        LocalDateTime(date: LocalDate(year: year, month: month, day: day), minuteOfDay: 10 * 60 + 30)
    }

    private static func makeFixture() throws -> (
        repository: AppointmentsRepositoryImpl,
        dao: AppointmentDao,
        scheduler: RecordingReminderScheduler,
        clock: FixedSalusClock
    ) {
        let clock = FixedSalusClock(now: now, timeZone: zone)
        let dao = try AppointmentDao(database: SalusDatabase.inMemory(clock: clock))
        let scheduler = RecordingReminderScheduler()
        let repository = AppointmentsRepositoryImpl(
            appointmentDao: dao,
            reminderScheduler: scheduler,
            clock: clock
        )
        return (repository, dao, scheduler, clock)
    }
}

extension Appointment {
    /// The twin of Kotlin's `data class` `copy(...)`, limited to the four fields these tests vary.
    /// Swift has no synthesised `copy`, and a memberwise call per variation would bury the one
    /// field that differs under ten that do not.
    fileprivate func with(
        id: String? = nil,
        startsAt: LocalDateTime? = nil,
        status: AppointmentStatus? = nil,
        reminderOffsetsMinutes: [Int]? = nil
    ) -> Appointment {
        Appointment(
            id: id ?? self.id,
            title: title,
            doctorName: doctorName,
            specialty: specialty,
            location: location,
            notes: notes,
            startsAt: startsAt ?? self.startsAt,
            timeZone: timeZone,
            durationMinutes: durationMinutes,
            status: status ?? self.status,
            reminderOffsetsMinutes: reminderOffsetsMinutes ?? self.reminderOffsetsMinutes
        )
    }
}
