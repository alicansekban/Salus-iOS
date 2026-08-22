// One populated instance of each of the thirteen records, in an order that satisfies the foreign
// keys, so `RoomSchemaParityTests` can ask two questions of every table without thirteen
// near-identical test functions: does the record encode exactly this table's columns, and does it
// survive a real insert and read back unchanged?
//
// Every optional is filled in. A `nil` would prove nothing about the column behind it.

import GRDB
import Testing

@testable import SalusDatabase

/// A record with its type erased down to what the parity tests need from it.
struct SampleRecord {
    let tableName: String
    /// The column names the record actually writes — what GRDB derives from its `CodingKeys`.
    /// Encoding a record can fail, so this stays a call rather than a stored set.
    let encodedColumns: @Sendable () throws -> Set<String>
    /// Inserts the record and checks the table gives it back identical.
    let insertAndReadBack: @Sendable (Database) throws -> Void

    init<Record>(_ record: Record) where Record: FetchableRecord & PersistableRecord & Equatable & Sendable {
        tableName = Record.databaseTableName
        encodedColumns = { try Set(record.databaseDictionary.keys) }
        insertAndReadBack = { db in
            try record.insert(db)
            let stored = try Record.fetchAll(db)
            #expect(stored.contains(record), "\(Record.databaseTableName) did not give back what it was given")
        }
    }
}

enum SampleRecords {
    /// The owning profile of everything below. `SalusDatabase.defaultProfileId` is already seeded
    /// by the v1 migration, so this is a second, fully populated row.
    static let profileId = "sample-profile"

    static let all: [SampleRecord] = [
        SampleRecord(profile),
        SampleRecord(appointment),
        SampleRecord(appointmentReminder),
        SampleRecord(medication),
        SampleRecord(medicationSchedule),
        SampleRecord(medicationIntakeLog),
        SampleRecord(cyclePeriod),
        SampleRecord(cycleDailyEntry),
        SampleRecord(symptom),
        SampleRecord(cycleEntrySymptom),
        SampleRecord(vitalsMeasurement),
        SampleRecord(reminderAlarm),
        SampleRecord(aiSummary)
    ]

    static let profile = ProfileRecord(
        id: profileId,
        displayName: "Ada",
        birthDateEpochDay: 7000,
        sex: "FEMALE",
        heightCm: 170.0,
        healthNotes: "Penisilin alerjisi",
        isDefault: false,
        createdAtEpochMs: 42
    )

    static let appointment = AppointmentRecord(
        id: "appointment-1",
        profileId: profileId,
        title: "Kardiyoloji kontrolü",
        doctorName: "Dr. Yılmaz",
        specialty: "CARDIOLOGY",
        location: "Kadıköy",
        notes: "Aç karnına",
        startsAtLocal: "2026-09-01T14:30",
        timeZoneId: "Europe/Istanbul",
        startsAtEpochMs: 1_788_000_000_000,
        durationMinutes: 30,
        status: "SCHEDULED",
        createdAtEpochMs: 1,
        updatedAtEpochMs: 2
    )

    static let appointmentReminder = AppointmentReminderRecord(
        id: "appointment-reminder-1",
        appointmentId: appointment.id,
        offsetMinutes: 60,
        enabled: true
    )

    static let medication = MedicationRecord(
        id: "medication-1",
        profileId: profileId,
        name: "Metformin",
        form: "TABLET",
        strengthValue: 500.0,
        strengthUnit: "mg",
        colorToken: "MED_BLUE",
        instructions: "Yemekten sonra",
        stockCount: 30.0,
        stockThreshold: 5.0,
        startDateEpochDay: 20685,
        endDateEpochDay: 20800,
        isActive: true,
        createdAtEpochMs: 3,
        updatedAtEpochMs: 4
    )

    static let medicationSchedule = MedicationScheduleRecord(
        id: "medication-schedule-1",
        medicationId: medication.id,
        recurrence: "DAYS_OF_WEEK",
        daysOfWeekMask: 0b1010101,
        intervalDays: 2,
        anchorDateEpochDay: 20685,
        timeOfDayMinutes: 8 * 60,
        doseAmount: 1.5,
        isActive: true
    )

    static let medicationIntakeLog = MedicationIntakeLogRecord(
        id: "medication-intake-log-1",
        scheduleId: medicationSchedule.id,
        medicationId: medication.id,
        profileId: profileId,
        scheduledDateEpochDay: 20685,
        scheduledMinutes: 8 * 60,
        status: "TAKEN",
        takenAtEpochMs: 1_788_000_060_000,
        snoozedUntilEpochMs: 1_788_000_600_000,
        doseAmount: 1.5,
        note: "Not"
    )

    static let cyclePeriod = CyclePeriodRecord(
        id: "cycle-period-1",
        profileId: profileId,
        startDateEpochDay: 20685,
        endDateEpochDay: 20690,
        flowPeak: "HEAVY",
        note: "Not",
        createdAtEpochMs: 5
    )

    static let cycleDailyEntry = CycleDailyEntryRecord(
        id: "cycle-daily-entry-1",
        profileId: profileId,
        dateEpochDay: 20686,
        flow: "MEDIUM",
        mood: "CALM",
        note: "Not"
    )

    static let symptom = SymptomRecord(
        id: "symptom-1",
        nameKey: "symptom_cramps",
        isCustom: false,
        iconToken: "CRAMPS"
    )

    static let cycleEntrySymptom = CycleEntrySymptomRecord(
        entryId: cycleDailyEntry.id,
        symptomId: symptom.id,
        severity: 3
    )

    static let vitalsMeasurement = VitalsMeasurementRecord(
        id: "vitals-measurement-1",
        profileId: profileId,
        type: "BLOOD_PRESSURE",
        measuredAtEpochMs: 1_788_000_000_000,
        timeZoneId: "Europe/Istanbul",
        valuePrimary: 120.0,
        valueSecondary: 80.0,
        valueTertiary: 68.0,
        unit: "mmHg",
        measurementContext: "RESTING",
        note: "Not"
    )

    static let reminderAlarm = ReminderAlarmRecord(
        id: "reminder-alarm-1",
        type: "MEDICATION",
        entityId: medicationSchedule.id,
        occurrenceKey: "2026-09-01T08:00",
        triggerAtEpochMs: 1_788_000_000_000,
        requestCode: 12345,
        state: "SCHEDULED"
    )

    static let aiSummary = AiSummaryRecord(
        periodType: "WEEKLY",
        startEpochDay: 20685,
        endEpochDay: 20691,
        language: "tr",
        text: "Haftalık özet",
        createdAtEpochMs: 6
    )
}
