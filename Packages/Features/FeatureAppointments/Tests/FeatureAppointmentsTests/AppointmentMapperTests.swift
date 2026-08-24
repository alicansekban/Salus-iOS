// Ported 1:1 from `feature/appointments/src/test/kotlin/com/alicansekban/salus/feature/
// appointments/data/AppointmentMapperTest.kt`.
//
// Four cases, in the Kotlin order, with the Kotlin fixture and the Kotlin expectations. The names
// carry the Kotlin wording with the ported symbol names substituted — `toEntity` is `toRecord`
// here and `AppointmentEntity` is `AppointmentRecord`, because `SalusDatabase` calls a row a
// record. Two iOS-only cases follow, for the two stored values Kotlin reads with a throwing
// stdlib call and Swift reads with a failable initialiser.

import Foundation
import SalusCommon
import SalusDatabase
import SalusModel
import SalusTesting
import Testing

@testable import FeatureAppointments

@Suite("AppointmentMapper")
struct AppointmentMapperTests {
    /// `AppointmentMapperTest.kt:15` — `TimeZone.of("Europe/Istanbul")`, the zone
    /// `FixedSalusClock` already resolves (with a documented fallback, so no force unwrap here).
    private static let zone = FixedSalusClock.defaultZone

    /// `AppointmentMapperTest.kt:17-29`.
    private static let appointment = Appointment(
        id: "a1",
        title: "Dental checkup",
        doctorName: "Dr. X",
        specialty: "Dentistry",
        location: "Clinic A",
        notes: "Bring old x-rays",
        startsAt: LocalDateTime(date: LocalDate(year: 2026, month: 9, day: 1), minuteOfDay: 10 * 60 + 30),
        timeZone: zone,
        durationMinutes: 45,
        status: .scheduled,
        reminderOffsetsMinutes: [60, 1440]
    )

    /// `AppointmentMapperTest.kt:31-51`.
    @Test("toRecord writes ISO local date-time and correct epoch cache")
    func toRecordWritesIsoLocalDateTimeAndCorrectEpochCache() throws {
        let record = Self.appointment.toRecord(
            profileId: "default-profile",
            createdAtEpochMs: 1,
            updatedAtEpochMs: 2
        )

        #expect(record.startsAtLocal == "2026-09-01T10:30")
        #expect(record.timeZoneId == "Europe/Istanbul")
        // Independent expectation, the twin of the Kotlin test's `java.time.ZonedDateTime` one:
        // Istanbul is UTC+3 on that date, so the wall clock 10:30 is 07:30Z.
        let expected = try #require(ISO8601DateFormatter().date(from: "2026-09-01T07:30:00Z"))
        #expect(record.startsAtEpochMs == expected.epochMilliseconds)
        #expect(record.status == "SCHEDULED")
        #expect(record.profileId == "default-profile")
        #expect(record.createdAtEpochMs == 1)
        #expect(record.updatedAtEpochMs == 2)
    }

    /// `AppointmentMapperTest.kt:53-64`. The ids are what makes a save a *replace*: the same
    /// offset on the same appointment always names the same row, so no generator is needed and no
    /// duplicate can accumulate.
    @Test("toReminderRecords produces deterministic enabled rows")
    func toReminderRecordsProducesDeterministicEnabledRows() {
        let reminders = Self.appointment.toReminderRecords()

        #expect(reminders.map(\.id) == ["a1:60", "a1:1440"])
        #expect(reminders.map(\.offsetMinutes) == [60, 1440])
        #expect(reminders.map(\.enabled) == [true, true])
        #expect(reminders.map(\.appointmentId) == ["a1", "a1"])
    }

    /// `AppointmentMapperTest.kt:66-72`.
    @Test("record round trip preserves the domain model")
    func recordRoundTripPreservesTheDomainModel() throws {
        let record = Self.appointment.toRecord(profileId: "default-profile", createdAtEpochMs: 1, updatedAtEpochMs: 2)

        let roundTripped = try record.toDomain(reminders: Self.appointment.toReminderRecords())

        #expect(roundTripped == Self.appointment)
    }

    /// `AppointmentMapperTest.kt:74-87` — the domain model carries the *enabled* offsets, ascending,
    /// whatever order and state the rows are stored in.
    @Test("disabled reminders are excluded and offsets sorted")
    func disabledRemindersAreExcludedAndOffsetsSorted() throws {
        let record = Self.appointment.toRecord(profileId: "default-profile", createdAtEpochMs: 1, updatedAtEpochMs: 2)
        let reminders = [
            AppointmentReminderRecord(id: "r1", appointmentId: "a1", offsetMinutes: 1440, enabled: true),
            AppointmentReminderRecord(id: "r2", appointmentId: "a1", offsetMinutes: 60, enabled: true),
            AppointmentReminderRecord(id: "r3", appointmentId: "a1", offsetMinutes: 10080, enabled: false)
        ]

        let domain = try record.toDomain(reminders: reminders)

        #expect(domain.reminderOffsetsMinutes == [60, 1440])
    }

    /// iOS-only, and the Vitals precedent (`WeightEntryMapperTests.anUnresolvableStoredTimeZoneId`):
    /// `kotlinx.datetime.TimeZone.of` throws for an identifier the platform cannot resolve, and so
    /// does this. Degrading to GMT would move the appointment to another hour of the day silently.
    @Test("an unresolvable stored time zone id throws")
    func anUnresolvableStoredTimeZoneIdThrows() {
        let record = Self.record(timeZoneId: "Mars/Olympus_Mons")

        #expect(throws: IllegalTimeZoneError.unknownTimeZone("Mars/Olympus_Mons")) {
            try record.toDomain(reminders: [])
        }
    }

    /// iOS-only: Kotlin reads these two columns with `LocalDateTime.parse` and
    /// `AppointmentStatus.valueOf`, both of which throw on a value they cannot read. Swift's twins
    /// are failable initialisers, so the mapper has to raise the failure itself — this pins that it
    /// does rather than substituting a default and hiding a corrupt row.
    @Test("a stored value the platform cannot read throws")
    func aStoredValueThePlatformCannotReadThrows() {
        #expect(throws: MalformedAppointmentRecordError.startsAtLocal("2026-09-01T10:30+03:00")) {
            try Self.record(startsAtLocal: "2026-09-01T10:30+03:00").toDomain(reminders: [])
        }
        #expect(throws: MalformedAppointmentRecordError.status("ARCHIVED")) {
            try Self.record(status: "ARCHIVED").toDomain(reminders: [])
        }
    }

    private static func record(
        startsAtLocal: String = "2026-09-01T10:30",
        timeZoneId: String? = nil,
        status: String = "SCHEDULED"
    ) -> AppointmentRecord {
        AppointmentRecord(
            id: "a1",
            profileId: "default-profile",
            title: "Dental checkup",
            doctorName: nil,
            specialty: nil,
            location: nil,
            notes: nil,
            startsAtLocal: startsAtLocal,
            timeZoneId: timeZoneId ?? zone.identifier,
            startsAtEpochMs: 0,
            durationMinutes: 45,
            status: status,
            createdAtEpochMs: 1,
            updatedAtEpochMs: 2
        )
    }
}
