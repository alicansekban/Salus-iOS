// Ported 1:1 from `feature/appointments/src/test/kotlin/com/alicansekban/salus/feature/
// appointments/reminder/AppointmentReminderHandlerTest.kt`.
//
// Eight cases, in the Kotlin order, with the Kotlin fixture (`Europe/Istanbul`, the same fixed
// instant) and the Kotlin expectations. Each one cites the Kotlin line it comes from, so a change
// on either side that is not made on the other is visible in the diff.
//
// The second suite below has no Kotlin twin: Android's `AndroidAppointmentNotificationTexts` reads
// `Context` and is not JVM-testable, so the module never tested it. The Swift implementation needs
// no `Context`, and the parts of it that can drift silently — the date pattern, the blank filter
// and the " · " joining — are pinned here in two explicit locales.

import Foundation
import SalusCommon
import SalusModel
import SalusReminder
import SalusTesting
import Testing

@testable import FeatureAppointments

@Suite("AppointmentReminderHandler")
struct AppointmentReminderHandlerTests {
    /// `AppointmentReminderHandlerTest.kt:29` — `TimeZone.of("Europe/Istanbul")`.
    private static let zone = FixedSalusClock.defaultZone
    /// `AppointmentReminderHandlerTest.kt:30` — 1_755_000_000_000 ms.
    private static let now = Date(timeIntervalSince1970: 1_755_000_000)

    private static let hour: TimeInterval = 3600
    private static let day: TimeInterval = 86400
    private static let minute: TimeInterval = 60

    private let repository: FakeAppointmentsRepository
    private let handler: AppointmentReminderHandler

    init() {
        // `AppointmentReminderHandlerTest.kt:31-42`.
        let repository = FakeAppointmentsRepository(zone: Self.zone)
        self.repository = repository
        handler = AppointmentReminderHandler(
            repository: repository,
            clock: FixedSalusClock(now: Self.now, timeZone: Self.zone),
            texts: FakeAppointmentNotificationTexts()
        )
    }

    /// `AppointmentReminderHandlerTest.kt:60-63`.
    @Test("handler type is APPOINTMENT")
    func handlerTypeIsAppointment() {
        #expect(handler.type == .appointment)
    }

    /// `AppointmentReminderHandlerTest.kt:65-82` — one occurrence per offset, each keyed by the
    /// appointment id and the offset so the engine can recognise the same trigger across syncs.
    @Test("occurrences apply each offset with stable keys")
    func occurrencesApplyEachOffsetWithStableKeys() async throws {
        repository.setAppointments(
            Self.appointment(id: "a1", startsIn: 2 * Self.day, offsets: [60, 1440])
        )

        let occurrences = try await handler
            .occurrencesBetween(from: Self.now, until: Self.now + 48 * Self.hour)
            .sorted { $0.triggerAt < $1.triggerAt }

        #expect(occurrences.count == 2)
        #expect(occurrences[0].occurrenceKey == "a1|1440")
        #expect(occurrences[0].triggerAt == Self.now + 2 * Self.day - 1440 * Self.minute)
        #expect(occurrences[1].occurrenceKey == "a1|60")
        #expect(occurrences[1].triggerAt == Self.now + 2 * Self.day - 60 * Self.minute)
        #expect(occurrences.allSatisfy { $0.entityId == "a1" })
    }

    /// `AppointmentReminderHandlerTest.kt:84-96` — a trigger already behind `from` is gone, and one
    /// at or past `until` belongs to the next sync.
    @Test("triggers outside the window are excluded")
    func triggersOutsideTheWindowAreExcluded() async throws {
        repository.setAppointments(
            // 1-week offset trigger already in the past; 1-hour trigger inside the window.
            Self.appointment(id: "a1", startsIn: 2 * Self.hour, offsets: [60, 10080]),
            // Starts beyond the window and the offset does not pull it inside.
            Self.appointment(id: "a2", startsIn: 10 * Self.day, offsets: [60])
        )

        let occurrences = try await handler.occurrencesBetween(from: Self.now, until: Self.now + 48 * Self.hour)

        #expect(occurrences.map(\.occurrenceKey) == ["a1|60"])
    }

    /// `AppointmentReminderHandlerTest.kt:98-105` — an appointment that already started is skipped
    /// whole, offsets and all.
    @Test("past appointments produce no occurrences")
    func pastAppointmentsProduceNoOccurrences() async throws {
        repository.setAppointments(
            Self.appointment(id: "past", startsIn: -2 * Self.hour, offsets: [60, 1440])
        )

        let occurrences = try await handler.occurrencesBetween(from: Self.now, until: Self.now + 48 * Self.hour)

        #expect(occurrences.isEmpty)
    }

    /// `AppointmentReminderHandlerTest.kt:107-117` — the engine diffs one sync against the next, so
    /// the same inputs must produce the same occurrences rather than merely equivalent ones.
    @Test("occurrence computation is deterministic across calls")
    func occurrenceComputationIsDeterministicAcrossCalls() async throws {
        repository.setAppointments(
            Self.appointment(id: "a1", startsIn: Self.day, offsets: [60])
        )

        let first = try await handler.occurrencesBetween(from: Self.now, until: Self.now + 48 * Self.hour)
        let second = try await handler.occurrencesBetween(from: Self.now, until: Self.now + 48 * Self.hour)

        #expect(first == second)
    }

    /// `AppointmentReminderHandlerTest.kt:119-122` — a reminder can fire after its appointment was
    /// deleted; there is nothing left to say.
    @Test("notificationContent is null for deleted appointment")
    func notificationContentIsNullForDeletedAppointment() async throws {
        let content = try await handler.notificationContent(for: Self.ref(entityId: "missing"))

        #expect(content == nil)
    }

    /// `AppointmentReminderHandlerTest.kt:124-134`.
    @Test("notificationContent is null for past or non-scheduled appointment")
    func notificationContentIsNullForPastOrNonScheduledAppointment() async throws {
        repository.setAppointments(
            Self.appointment(id: "past", startsIn: -Self.hour, offsets: [60]),
            Self.appointment(id: "cancelled", startsIn: Self.day, offsets: [60], status: .cancelled)
        )

        let past = try await handler.notificationContent(for: Self.ref(entityId: "past"))
        let cancelled = try await handler.notificationContent(for: Self.ref(entityId: "cancelled"))

        #expect(past == nil)
        #expect(cancelled == nil)
    }

    /// `AppointmentReminderHandlerTest.kt:136-149` — the handler never formats a string itself; it
    /// asks the injected texts, and it declares no actions.
    @Test("notificationContent uses feature texts for upcoming appointment")
    func notificationContentUsesFeatureTextsForUpcomingAppointment() async throws {
        repository.setAppointments(
            Self.appointment(id: "a1", startsIn: Self.day, offsets: [1440])
        )

        let content = try #require(try await handler.notificationContent(for: Self.ref(entityId: "a1")))

        #expect(content.title == "Appointment: Checkup a1")
        #expect(content.text.contains("Dr. X"))
        #expect(content.actions.isEmpty)
        // Not in the Kotlin table: appointments are never alarms (spec 6.1 / M11), and the
        // presentation is the one field that would silently escalate them.
        #expect(content.presentation == .notification)
    }

    /// `AppointmentReminderHandlerTest.kt:44-58`.
    private static func appointment(
        id: String,
        startsIn: TimeInterval,
        offsets: [Int],
        status: AppointmentStatus = .scheduled
    ) -> Appointment {
        Appointment(
            id: id,
            title: "Checkup \(id)",
            doctorName: "Dr. X",
            specialty: nil,
            location: "Clinic",
            notes: nil,
            startsAt: (now + startsIn).wallClock(in: zone),
            timeZone: zone,
            durationMinutes: 60,
            status: status,
            reminderOffsetsMinutes: offsets
        )
    }

    /// `AppointmentReminderHandlerTest.kt:151-155`.
    private static func ref(entityId: String) -> ReminderRef {
        ReminderRef(type: .appointment, entityId: entityId, occurrenceKey: "\(entityId)|60")
    }
}

/// `AppointmentReminderHandlerTest.kt:33-38` — the anonymous `AppointmentNotificationTexts` the
/// Kotlin test declares inline, which keeps the handler's assertions about *delegation* rather
/// than about copy. Swift cannot declare a conformance inline, so it is a named struct.
private struct FakeAppointmentNotificationTexts: AppointmentNotificationTexts {
    func title(appointmentTitle: String) -> String {
        "Appointment: \(appointmentTitle)"
    }

    func body(startsAt: LocalDateTime, doctorName: String?, location: String?) -> String {
        ([startsAt.isoLocalString] + [doctorName, location].compactMap(\.self)).joined(separator: " · ")
    }
}

@Suite("LocalizedAppointmentNotificationTexts")
struct LocalizedAppointmentNotificationTextsTests {
    /// 2026-08-24T14:30, a wall clock with a two-digit day and a non-zero minute so neither field
    /// can be padded wrong unnoticed.
    private static let startsAt = LocalDateTime(
        date: LocalDate(year: 2026, month: 8, day: 24),
        minuteOfDay: 14 * 60 + 30
    )

    /// The locale is injected rather than read from the device precisely so this assertion is a
    /// fact rather than a reading of whatever region the test host is set to.
    @Test("body renders the start with the Android pattern in the given locale")
    func bodyRendersTheStartWithTheAndroidPattern() {
        let turkish = LocalizedAppointmentNotificationTexts(locale: Locale(identifier: "tr_TR"))
        let english = LocalizedAppointmentNotificationTexts(locale: Locale(identifier: "en_US"))

        #expect(turkish.body(startsAt: Self.startsAt, doctorName: nil, location: nil) == "24 Ağu 2026, 14:30")
        #expect(english.body(startsAt: Self.startsAt, doctorName: nil, location: nil) == "24 Aug 2026, 14:30")
    }

    /// `AndroidAppointmentNotificationTexts.kt:24` — `listOfNotNull(doctorName, location)`, in that
    /// order, appended to the formatted start.
    @Test("body appends the doctor and the location in order")
    func bodyAppendsTheDoctorAndTheLocationInOrder() {
        let texts = LocalizedAppointmentNotificationTexts(locale: Locale(identifier: "en_US"))

        let body = texts.body(startsAt: Self.startsAt, doctorName: "Dr. X", location: "Clinic")

        #expect(body == "24 Aug 2026, 14:30 · Dr. X · Clinic")
    }

    /// `AndroidAppointmentNotificationTexts.kt:24` — `.filter { it.isNotBlank() }`, so a
    /// whitespace-only column never becomes a trailing separator.
    @Test("body drops blank details")
    func bodyDropsBlankDetails() {
        let texts = LocalizedAppointmentNotificationTexts(locale: Locale(identifier: "en_US"))

        let onlyLocation = texts.body(startsAt: Self.startsAt, doctorName: "   ", location: "Clinic")
        let neither = texts.body(startsAt: Self.startsAt, doctorName: nil, location: "")

        #expect(onlyLocation == "24 Aug 2026, 14:30 · Clinic")
        #expect(neither == "24 Aug 2026, 14:30")
    }
}
