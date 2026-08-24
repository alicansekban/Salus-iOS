// Ported from the `deleting appointment cascades its reminders` case of
// `core/database/src/test/kotlin/com/alicansekban/salus/core/database/DaoSmokeTest.kt:68-99`,
// plus the query, ordering and observation halves Android leaves to Turbine and to the SQL itself.
//
// As in `VitalsDaoTests`, the fixture is `SalusDatabase.inMemory`, which runs the migrations — so
// the seeded default profile is already there and the Kotlin `p1` profile is a second row.

import Foundation
import GRDB
import SalusTesting
import Testing

@testable import SalusDatabase

@Suite("AppointmentDao")
struct AppointmentDaoTests {
    private let clock = FixedSalusClock(now: Date(timeIntervalSince1970: 1_700_000_000))

    /// `DaoSmokeTest.kt:68-99`, verbatim: `appointment_reminders.appointment_id` is a cascading
    /// foreign key, so deleting the appointment takes its reminder rows with it.
    @Test("deleting appointment cascades its reminders")
    func deletingAppointmentCascadesItsReminders() async throws {
        let dao = try await makeDao()
        try await dao.upsertWithReminders(
            Self.appointment(id: "a1", startsAt: 1_756_000_000_000),
            reminders: [
                AppointmentReminderRecord(id: "r1", appointmentId: "a1", offsetMinutes: 120, enabled: true),
                AppointmentReminderRecord(id: "r2", appointmentId: "a1", offsetMinutes: 1440, enabled: true)
            ]
        )
        #expect(try await dao.getRemindersFor(appointmentId: "a1").count == 2)

        try await dao.deleteById("a1")

        #expect(try await dao.getRemindersFor(appointmentId: "a1").isEmpty)
        #expect(try await dao.getById("a1") == nil)
    }

    /// `AppointmentDao.kt:20-28` — the transaction is upsert → delete → upsert, so a second save
    /// leaves exactly the reminder rows it was handed, not those plus the previous ones.
    @Test("upsertWithReminders replaces the reminder rows it finds")
    func upsertWithRemindersReplacesTheReminderRows() async throws {
        let dao = try await makeDao()
        try await dao.upsertWithReminders(
            Self.appointment(id: "a1", startsAt: 1000),
            reminders: [
                AppointmentReminderRecord(id: "a1:60", appointmentId: "a1", offsetMinutes: 60, enabled: true),
                AppointmentReminderRecord(id: "a1:1440", appointmentId: "a1", offsetMinutes: 1440, enabled: true)
            ]
        )

        try await dao.upsertWithReminders(
            Self.appointment(id: "a1", startsAt: 2000, title: "Yeni başlık"),
            reminders: [
                AppointmentReminderRecord(id: "a1:10080", appointmentId: "a1", offsetMinutes: 10080, enabled: true)
            ]
        )

        let stored = try await dao.getRemindersFor(appointmentId: "a1")
        #expect(stored.map(\.id) == ["a1:10080"])
        let appointment = try #require(try await dao.getById("a1"))
        #expect(appointment.title == "Yeni başlık")
        #expect(appointment.startsAtEpochMs == 2000)
    }

    /// The upsert half of the same transaction replaces the row that shares the primary key rather
    /// than adding a second one (`AppointmentDao.kt:14-15`).
    @Test("upsert replaces the appointment that shares the id")
    func upsertReplacesTheAppointmentThatSharesTheId() async throws {
        let dao = try await makeDao()
        try await dao.upsert(Self.appointment(id: "a1", startsAt: 1000))

        try await dao.upsert(Self.appointment(id: "a1", startsAt: 3000))

        #expect(try await dao.getById("a1")?.startsAtEpochMs == 3000)
        #expect(try await dao.getScheduled(profileId: "p1").count == 1)
    }

    /// `AppointmentDao.kt:17-18` — reminder rows written on their own, keyed by their own id.
    @Test("upsertReminders writes the rows and replaces those that share an id")
    func upsertRemindersWritesAndReplaces() async throws {
        let dao = try await makeDao()
        try await dao.upsert(Self.appointment(id: "a1", startsAt: 1000))

        try await dao.upsertReminders([
            AppointmentReminderRecord(id: "a1:60", appointmentId: "a1", offsetMinutes: 60, enabled: true)
        ])
        try await dao.upsertReminders([
            AppointmentReminderRecord(id: "a1:60", appointmentId: "a1", offsetMinutes: 60, enabled: false)
        ])

        let stored = try await dao.getRemindersFor(appointmentId: "a1")
        #expect(stored == [
            AppointmentReminderRecord(id: "a1:60", appointmentId: "a1", offsetMinutes: 60, enabled: false)
        ])
    }

    /// `AppointmentDao.kt:60-61` — the reminder rows go without the appointment going with them.
    @Test("deleteRemindersFor clears one appointment's rows and leaves the appointment")
    func deleteRemindersForClearsOnlyTheReminders() async throws {
        let dao = try await makeDao()
        try await dao.upsertWithReminders(
            Self.appointment(id: "a1", startsAt: 1000),
            reminders: [
                AppointmentReminderRecord(id: "a1:60", appointmentId: "a1", offsetMinutes: 60, enabled: true)
            ]
        )
        try await dao.upsertWithReminders(
            Self.appointment(id: "a2", startsAt: 2000),
            reminders: [
                AppointmentReminderRecord(id: "a2:60", appointmentId: "a2", offsetMinutes: 60, enabled: true)
            ]
        )

        try await dao.deleteRemindersFor(appointmentId: "a1")

        #expect(try await dao.getRemindersFor(appointmentId: "a1").isEmpty)
        #expect(try await dao.getRemindersFor(appointmentId: "a2").map(\.id) == ["a2:60"])
        #expect(try await dao.getById("a1") != nil)
    }

    @Test("getById answers nil for an id that is not there")
    func getByIdAnswersNilForAnUnknownId() async throws {
        let dao = try await makeDao()

        #expect(try await dao.getById("nope") == nil)
    }

    /// `AppointmentDao.kt:39-46` — from the instant onward, scheduled only, soonest first. The
    /// boundary is `>=`, so an appointment starting exactly at the instant is still upcoming.
    @Test("observeUpcoming lists the scheduled appointments from the instant onward, soonest first")
    func observeUpcomingListsScheduledFromTheInstantOnward() async throws {
        let dao = try await makeDao()
        try await dao.upsert(Self.appointment(id: "later", startsAt: 3000))
        try await dao.upsert(Self.appointment(id: "at-the-bound", startsAt: 2000))
        try await dao.upsert(Self.appointment(id: "before", startsAt: 1999))
        try await dao.upsert(Self.appointment(id: "cancelled", startsAt: 2500, status: "CANCELLED"))
        try await dao.upsert(Self.appointment(
            id: "other-profile",
            startsAt: 2500,
            profileId: SalusDatabase.defaultProfileId
        ))

        var iterator = dao.observeUpcoming(profileId: "p1", fromEpochMs: 2000).makeAsyncIterator()

        let items = try #require(try await iterator.next())
        #expect(items.map(\.id) == ["at-the-bound", "later"])
    }

    /// `AppointmentDao.kt:48-55` — everything that already started *or* is no longer scheduled,
    /// newest first. A `COMPLETED` appointment in the future is past, however far away it is.
    @Test("observePast lists what already started or is no longer scheduled, newest first")
    func observePastListsStartedOrNoLongerScheduled() async throws {
        let dao = try await makeDao()
        try await dao.upsert(Self.appointment(id: "older", startsAt: 500))
        try await dao.upsert(Self.appointment(id: "newer", startsAt: 1999))
        try await dao.upsert(Self.appointment(id: "completed-in-the-future", startsAt: 9000, status: "COMPLETED"))
        try await dao.upsert(Self.appointment(id: "still-scheduled", startsAt: 2000))
        try await dao.upsert(Self.appointment(
            id: "other-profile",
            startsAt: 500,
            profileId: SalusDatabase.defaultProfileId
        ))

        var iterator = dao.observePast(profileId: "p1", beforeEpochMs: 2000).makeAsyncIterator()

        let items = try #require(try await iterator.next())
        #expect(items.map(\.id) == ["completed-in-the-future", "newer", "older"])
    }

    /// `AppointmentDao.kt:33-34` — the current row, then a fresh one after every transaction that
    /// changes it, and nil once it is gone (which is what closes the detail screen).
    @Test("observeById emits the row, its update, and nil once it is deleted")
    func observeByIdEmitsRowUpdateAndNil() async throws {
        let dao = try await makeDao()
        try await dao.upsert(Self.appointment(id: "a1", startsAt: 1000))

        var iterator = dao.observeById("a1").makeAsyncIterator()

        let first = try #require(try await iterator.next())
        #expect(first?.startsAtEpochMs == 1000)

        try await dao.upsert(Self.appointment(id: "a1", startsAt: 2000))
        let updated = try #require(try await iterator.next())
        #expect(updated?.startsAtEpochMs == 2000)

        try await dao.deleteById("a1")
        let deleted = try #require(try await iterator.next())
        #expect(deleted == nil)
    }

    /// `AppointmentDao.kt:36-37`.
    @Test("observeRemindersFor emits one appointment's reminder rows")
    func observeRemindersForEmitsOneAppointmentsRows() async throws {
        let dao = try await makeDao()
        try await dao.upsertWithReminders(
            Self.appointment(id: "a1", startsAt: 1000),
            reminders: [
                AppointmentReminderRecord(id: "a1:60", appointmentId: "a1", offsetMinutes: 60, enabled: true)
            ]
        )
        try await dao.upsertWithReminders(
            Self.appointment(id: "a2", startsAt: 2000),
            reminders: [
                AppointmentReminderRecord(id: "a2:60", appointmentId: "a2", offsetMinutes: 60, enabled: true)
            ]
        )

        var iterator = dao.observeRemindersFor(appointmentId: "a1").makeAsyncIterator()

        let items = try #require(try await iterator.next())
        #expect(items.map(\.id) == ["a1:60"])
    }

    /// `AppointmentDao.kt:72-79` — the join is what scopes reminder rows to a profile;
    /// `appointment_reminders` itself carries no `profile_id`.
    @Test("observeRemindersForProfile joins through appointments and skips another profile")
    func observeRemindersForProfileSkipsAnotherProfile() async throws {
        let dao = try await makeDao()
        try await dao.upsertWithReminders(
            Self.appointment(id: "mine", startsAt: 1000),
            reminders: [
                AppointmentReminderRecord(id: "mine:60", appointmentId: "mine", offsetMinutes: 60, enabled: true)
            ]
        )
        try await dao.upsertWithReminders(
            Self.appointment(id: "theirs", startsAt: 1000, profileId: SalusDatabase.defaultProfileId),
            reminders: [
                AppointmentReminderRecord(id: "theirs:60", appointmentId: "theirs", offsetMinutes: 60, enabled: true)
            ]
        )

        var iterator = dao.observeRemindersForProfile(profileId: "p1").makeAsyncIterator()

        let items = try #require(try await iterator.next())
        #expect(items.map(\.id) == ["mine:60"])
    }

    /// `AppointmentDao.kt:66-67` — one profile's scheduled appointments, in no promised order.
    @Test("getScheduled returns one profile's scheduled appointments only")
    func getScheduledReturnsOneProfilesScheduledOnly() async throws {
        let dao = try await makeDao()
        try await dao.upsert(Self.appointment(id: "scheduled", startsAt: 1000))
        try await dao.upsert(Self.appointment(id: "completed", startsAt: 1000, status: "COMPLETED"))
        try await dao.upsert(Self.appointment(id: "cancelled", startsAt: 1000, status: "CANCELLED"))
        try await dao.upsert(Self.appointment(
            id: "other-profile",
            startsAt: 1000,
            profileId: SalusDatabase.defaultProfileId
        ))

        let scheduled = try await dao.getScheduled(profileId: "p1")

        #expect(scheduled.map(\.id) == ["scheduled"])
    }

    /// `AppointmentDao.kt:69-70` — one batched read instead of one per appointment.
    @Test("getRemindersForAppointments reads every named appointment's rows in one query")
    func getRemindersForAppointmentsReadsEveryNamedAppointment() async throws {
        let dao = try await makeDao()
        for id in ["a1", "a2", "a3"] {
            try await dao.upsertWithReminders(
                Self.appointment(id: id, startsAt: 1000),
                reminders: [
                    AppointmentReminderRecord(id: "\(id):60", appointmentId: id, offsetMinutes: 60, enabled: true)
                ]
            )
        }

        let reminders = try await dao.getRemindersForAppointments(ids: ["a1", "a3"])

        #expect(Set(reminders.map(\.id)) == ["a1:60", "a3:60"])
    }

    /// Room turns `IN (:ids)` on an empty list into a no-row query; raw SQLite would see
    /// `IN ()` and refuse to parse it, so the empty case never reaches the database.
    @Test("getRemindersForAppointments answers empty for an empty id list")
    func getRemindersForAppointmentsAnswersEmptyForAnEmptyList() async throws {
        let dao = try await makeDao()
        try await dao.upsertWithReminders(
            Self.appointment(id: "a1", startsAt: 1000),
            reminders: [
                AppointmentReminderRecord(id: "a1:60", appointmentId: "a1", offsetMinutes: 60, enabled: true)
            ]
        )

        #expect(try await dao.getRemindersForAppointments(ids: []).isEmpty)
    }

    /// The Kotlin fixture's `p1` profile (`DaoSmokeTest.kt:34-43`), which every appointment below
    /// hangs off — `appointments.profile_id` is a cascading foreign key.
    private func makeDao() async throws -> AppointmentDao {
        let database = try SalusDatabase.inMemory(clock: clock)
        try await ProfileDao(database: database).upsert(Self.profile)
        return AppointmentDao(database: database)
    }

    private static let profile = ProfileRecord(
        id: "p1",
        displayName: "Test",
        birthDateEpochDay: nil,
        sex: nil,
        heightCm: nil,
        healthNotes: nil,
        isDefault: true,
        createdAtEpochMs: 0
    )

    /// `DaoSmokeTest.kt:71-86`, with the profile, the status and the start opened up so the
    /// filtering tests can write a row the query is supposed to skip.
    private static func appointment(
        id: String,
        startsAt: Int64,
        title: String = "Cardiology check",
        profileId: String = "p1",
        status: String = "SCHEDULED"
    ) -> AppointmentRecord {
        AppointmentRecord(
            id: id,
            profileId: profileId,
            title: title,
            doctorName: nil,
            specialty: nil,
            location: nil,
            notes: nil,
            startsAtLocal: "2026-09-01T14:30",
            timeZoneId: "Europe/Istanbul",
            startsAtEpochMs: startsAt,
            durationMinutes: 30,
            status: status,
            createdAtEpochMs: 0,
            updatedAtEpochMs: 0
        )
    }
}
