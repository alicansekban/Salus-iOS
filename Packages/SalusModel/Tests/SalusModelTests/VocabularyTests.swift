import Testing

@testable import SalusModel

// Raw-value pinning tests for the whole domain vocabulary.
//
// Source of truth, copied by hand into the literals below:
// `salus-android/core/model/src/main/kotlin/com/alicansekban/salus/core/model/`
//   Appointment.kt · Cycle.kt · Medication.kt · Reminder.kt · Vitals.kt · Profile.kt ·
//   Settings.kt · MetricStats.kt
//
// Every enum constant here is a persisted string (spec §9): Room stores the enum `name` and the
// backup format carries it across platforms, so a renamed case or a reordered declaration is a
// data-format break, not a refactor. The lists are literal on purpose — deriving them from the
// Swift enum would assert nothing.
//
// `ThemeMode` and `PremiumTheme` are pinned by `ThemeSettingsTests`; they are not repeated here.

@Suite("Medication vocabulary (Medication.kt)")
struct MedicationVocabularyTests {
    @Test("MedicationForm raw values are the Kotlin constant names, in declaration order")
    func medicationFormRawValues() {
        // Medication.kt:3-12
        let expected = ["TABLET", "CAPSULE", "SYRUP", "INJECTION", "DROP", "INHALER", "CREAM", "OTHER"]
        #expect(MedicationForm.allCases.map(\.rawValue) == expected)
    }

    @Test("Recurrence raw values are the Kotlin constant names, in declaration order")
    func recurrenceRawValues() {
        // Medication.kt:14-19
        let expected = ["DAILY", "DAYS_OF_WEEK", "INTERVAL_DAYS", "AS_NEEDED"]
        #expect(Recurrence.allCases.map(\.rawValue) == expected)
    }

    @Test("IntakeStatus raw values are the Kotlin constant names, in declaration order")
    func intakeStatusRawValues() {
        // Medication.kt:21-26
        let expected = ["PENDING", "TAKEN", "SKIPPED", "MISSED"]
        #expect(IntakeStatus.allCases.map(\.rawValue) == expected)
    }
}

@Suite("Reminder vocabulary (Reminder.kt)")
struct ReminderVocabularyTests {
    @Test("ReminderType raw values are the Kotlin constant names, in declaration order")
    func reminderTypeRawValues() {
        // Reminder.kt:3-8
        // `SNOOZE` deleted 2026-08-23 as dead code, on both platforms.
        let expected = ["MEDICATION_DOSE", "APPOINTMENT", "CYCLE_PERIOD"]
        #expect(ReminderType.allCases.map(\.rawValue) == expected)
    }

    @Test("AlarmState raw values are the Kotlin constant names, in declaration order")
    func alarmStateRawValues() {
        // Reminder.kt:10-17
        let expected = ["SCHEDULED", "FIRED", "MISSED", "CANCELLED"]
        #expect(AlarmState.allCases.map(\.rawValue) == expected)
    }
}

@Suite("Vitals vocabulary (Vitals.kt)")
struct VitalsVocabularyTests {
    @Test("VitalType raw values are the Kotlin constant names, in declaration order")
    func vitalTypeRawValues() {
        // Vitals.kt:3-7
        let expected = ["WEIGHT", "BLOOD_PRESSURE", "BLOOD_GLUCOSE"]
        #expect(VitalType.allCases.map(\.rawValue) == expected)
    }

    @Test("MeasurementContext raw values are the Kotlin constant names, in declaration order")
    func measurementContextRawValues() {
        // Vitals.kt:9-14
        let expected = ["FASTING", "POST_MEAL", "BEDTIME", "RANDOM"]
        #expect(MeasurementContext.allCases.map(\.rawValue) == expected)
    }

    @Test("GlucoseUnit raw values are the Kotlin constant names, in declaration order")
    func glucoseUnitRawValues() {
        // Vitals.kt:16-19
        let expected = ["MG_DL", "MMOL_L"]
        #expect(GlucoseUnit.allCases.map(\.rawValue) == expected)
    }

    @Test("GlucoseUnit's default is the UserSettings default")
    func glucoseUnitDefault() {
        // Settings.kt:23
        #expect(GlucoseUnit.default == .mgDl)
    }

    @Test(
        "an unknown or absent stored GlucoseUnit falls back to the default, case-sensitively",
        arguments: [
            ("MG_DL", GlucoseUnit.mgDl),
            ("MMOL_L", GlucoseUnit.mmolL),
            // `toEnumOrDefault` matches `it.name == value` — no case folding.
            ("mmol_l", GlucoseUnit.mgDl),
            ("MMOL/L", GlucoseUnit.mgDl),
            ("", GlucoseUnit.mgDl),
            (nil, GlucoseUnit.mgDl)
        ] as [(stored: String?, expected: GlucoseUnit)]
    )
    func decodeStoredGlucoseUnit(_ row: (stored: String?, expected: GlucoseUnit)) {
        // Mirrors SalusPreferencesDataSource.kt:89-90, the shape `ThemeMode.fromStoredValue` uses.
        #expect(GlucoseUnit.fromStoredValue(row.stored) == row.expected, "stored \(row.stored ?? "nil")")
    }
}

@Suite("Appointment, cycle, profile and trend vocabulary")
struct RemainingVocabularyTests {
    @Test("AppointmentStatus raw values are the Kotlin constant names, in declaration order")
    func appointmentStatusRawValues() {
        // Appointment.kt:3-7
        let expected = ["SCHEDULED", "COMPLETED", "CANCELLED"]
        #expect(AppointmentStatus.allCases.map(\.rawValue) == expected)
    }

    @Test("FlowLevel raw values are the Kotlin constant names, in declaration order")
    func flowLevelRawValues() {
        // Cycle.kt:3-8
        let expected = ["SPOTTING", "LIGHT", "MEDIUM", "HEAVY"]
        #expect(FlowLevel.allCases.map(\.rawValue) == expected)
    }

    @Test("Mood raw values are the Kotlin constant names, in declaration order")
    func moodRawValues() {
        // Cycle.kt:10-17
        let expected = ["GREAT", "GOOD", "NEUTRAL", "LOW", "IRRITABLE", "ANXIOUS"]
        #expect(Mood.allCases.map(\.rawValue) == expected)
    }

    @Test("Sex raw values are the Kotlin constant names, in declaration order")
    func sexRawValues() {
        // Profile.kt:16-20
        let expected = ["FEMALE", "MALE", "OTHER"]
        #expect(Sex.allCases.map(\.rawValue) == expected)
    }

    @Test("Trend raw values are the Kotlin constant names, in declaration order")
    func trendRawValues() {
        // MetricStats.kt:6
        let expected = ["RISING", "FALLING", "STABLE"]
        #expect(Trend.allCases.map(\.rawValue) == expected)
    }
}

@Suite("UserSettings defaults (Settings.kt:17-34)")
struct UserSettingsDefaultsTests {
    @Test("a freshly constructed UserSettings carries Android's defaults, field for field")
    func defaults() {
        let settings = UserSettings()

        #expect(settings.themeMode == .system) // Settings.kt:18
        #expect(settings.appLockEnabled == false) // Settings.kt:19
        #expect(settings.secureScreenEnabled == false) // Settings.kt:21
        #expect(settings.onboardingCompleted == false) // Settings.kt:22
        #expect(settings.glucoseUnit == .mgDl) // Settings.kt:23
        #expect(settings.cycleReminderEnabled == false) // Settings.kt:25
        #expect(settings.cycleReminderLeadDays == 1) // Settings.kt:27
        #expect(settings.cycleReminderMinuteOfDay == 540) // Settings.kt:29, `9 * 60`
        #expect(settings.paywallIntroShown == false) // Settings.kt:31
        #expect(settings.premiumTheme == .classic) // Settings.kt:33
    }

    @Test("overriding one field leaves the other nine at their defaults")
    func partialOverride() {
        let settings = UserSettings(glucoseUnit: .mmolL)

        #expect(settings.glucoseUnit == .mmolL)
        #expect(settings == UserSettings(glucoseUnit: .mmolL))
        #expect(settings != UserSettings())
    }
}

@Suite("Profile (Profile.kt:5-14)")
struct ProfileTests {
    @Test("every optional field of the Kotlin data class is optional here too")
    func optionalFieldsAcceptNil() {
        let profile = Profile(
            id: "profile-1",
            displayName: "Ada",
            birthDate: nil,
            sex: nil,
            heightCm: nil,
            healthNotes: nil,
            isDefault: true
        )

        #expect(profile.birthDate == nil)
        #expect(profile.sex == nil)
        #expect(profile.heightCm == nil)
        #expect(profile.healthNotes == nil)
        #expect(profile.isDefault)
    }

    @Test("the birth date is a LocalDate, the kotlinx.datetime type's twin")
    func birthDateIsALocalDate() {
        let profile = Profile(
            id: "profile-1",
            displayName: "Ada",
            birthDate: LocalDate(year: 1990, month: 5, day: 17),
            sex: .female,
            heightCm: 168.0,
            healthNotes: "None",
            isDefault: false
        )

        #expect(profile.birthDate == LocalDate(year: 1990, month: 5, day: 17))
        #expect(profile.birthDate?.epochDay == 7441)
    }
}

/// A `DoseActions` stub that records the one call it accepts (`DoseActions.kt:9-12`).
private actor DoseActionsSpy: DoseActions {
    private(set) var calls: [(scheduleId: String, epochDay: Int, minuteOfDay: Int)] = []

    func markTaken(scheduleId: String, epochDay: Int, minuteOfDay: Int) async throws {
        calls.append((scheduleId, epochDay, minuteOfDay))
    }
}

/// A `VitalsQuickEntry` stub that rejects everything outside a plausible weight range, the way
/// the real weight editor does (`VitalsQuickEntry.kt:9-15`).
private actor VitalsQuickEntrySpy: VitalsQuickEntry {
    private(set) var lastEpochMs: Int64?

    func recordWeight(kilograms: Double, epochMs: Int64, timeZoneId: String) async throws -> Bool {
        lastEpochMs = epochMs
        return kilograms > 0 && !timeZoneId.isEmpty
    }
}

@Suite("Cross-feature contracts (DoseActions.kt, VitalsQuickEntry.kt)")
struct CrossFeatureContractsTests {
    @Test("DoseActions.markTaken carries the schedule id and the occurrence slot")
    func doseActionsSignature() async throws {
        let spy = DoseActionsSpy()

        try await spy.markTaken(scheduleId: "schedule-1", epochDay: 20687, minuteOfDay: 540)

        let calls = await spy.calls
        #expect(calls.count == 1)
        #expect(calls.first?.scheduleId == "schedule-1")
        #expect(calls.first?.epochDay == 20687)
        #expect(calls.first?.minuteOfDay == 540)
    }

    @Test("VitalsQuickEntry.recordWeight answers whether the measurement was written")
    func vitalsQuickEntrySignature() async throws {
        let spy = VitalsQuickEntrySpy()

        // `epochMs` is Kotlin's `Long`: this timestamp does not fit in 32 bits.
        let written = try await spy.recordWeight(
            kilograms: 72.5,
            epochMs: 1_787_000_000_000,
            timeZoneId: "Europe/Istanbul"
        )
        let rejected = try await spy.recordWeight(kilograms: -1.0, epochMs: 0, timeZoneId: "Europe/Istanbul")

        #expect(written)
        #expect(!rejected)
        #expect(await spy.lastEpochMs == 0)
    }
}
