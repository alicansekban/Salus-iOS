// Ported 1:1 from `feature/medications/src/test/kotlin/com/alicansekban/salus/feature/
// medications/reminder/MedicationReminderHandlerTest.kt`.
//
// Nine cases, in the Kotlin order, with the Kotlin fixture (`Europe/Istanbul`, 2026-03-02, a
// single 08:00 daily schedule) and the Kotlin expectations. Each one cites the Kotlin line it
// comes from, so a change on either side that is not made on the other is visible in the diff.
//
// Two cases have no Kotlin twin and are marked as such: Android's `when (actionId)` has no `else`
// branch, so nothing there pins what an unknown action does, and Kotlin asserts the action *ids*
// without asserting which one comes first by construction. On iOS both are load-bearing — the
// AlarmKit surface shows the FIRST action as its only secondary button — so they are pinned here.
//
// Kotlin's fixture reads `context.getString`, which Robolectric resolves against the real
// resources; the Swift twin injects a `FakeMedicationNotificationTexts` instead, for the reason
// `MedicationFormatting` already documents: `swift test` copies a `.xcstrings` into the resource
// bundle verbatim rather than compiling it, so a live lookup would answer with the key.

import Foundation
import SalusCommon
import SalusModel
import SalusReminder
import SalusTesting
import Testing

@testable import FeatureMedications

@Suite("MedicationReminderHandler")
struct MedicationReminderHandlerTests {
    /// `MedicationReminderHandlerTest.kt:40` — `TimeZone.of("Europe/Istanbul")`.
    private static let zone = FixedSalusClock.defaultZone
    /// `MedicationReminderHandlerTest.kt:41` — `LocalDate(2026, 3, 2)`.
    private static let day = LocalDate(year: 2026, month: 3, day: 2)
    /// `MedicationReminderHandlerTest.kt:42`.
    private static let dayEpoch = day.epochDay
    /// `MedicationReminderHandlerTest.kt:43` — local midnight on that day.
    private static let windowStart = LocalDateTime(date: day, minuteOfDay: 0).instant(in: zone)

    private static let hour: TimeInterval = 3600

    /// The 08:00 occurrence of the fixture day, the ref every case below acts on
    /// (`MedicationReminderHandlerTest.kt:83`).
    private static let doseRef = ReminderRef(
        type: .medicationDose,
        entityId: "sch-1",
        occurrenceKey: DoseOccurrenceKey.encode(epochDay: dayEpoch, minuteOfDay: 8 * 60)
    )

    private let repository: FakeMedicationRepository
    private let scheduler: FakeReminderScheduler
    private let clock: FixedSalusClock
    private let handler: MedicationReminderHandler

    init() {
        // `MedicationReminderHandlerTest.kt:45-64`.
        let repository = FakeMedicationRepository()
        repository.setMedications([
            MedicationWithSchedules(
                medication: testMedication(startDateEpochDay: 0),
                schedules: [testSchedule(timeOfDayMinutes: 8 * 60)]
            )
        ])
        let scheduler = FakeReminderScheduler()
        let clock = FixedSalusClock(now: Self.windowStart, timeZone: Self.zone)
        let idGenerator = FixedIdGenerator(id: "id")
        self.repository = repository
        self.scheduler = scheduler
        self.clock = clock
        handler = MedicationReminderHandler(
            repository: repository,
            markDoseTaken: MarkDoseTakenUseCase(
                repository: repository,
                clock: clock,
                idGenerator: idGenerator
            ),
            snoozeDose: SnoozeDoseUseCase(
                repository: repository,
                clock: clock,
                idGenerator: idGenerator,
                reminderScheduler: scheduler
            ),
            clock: clock,
            texts: FakeMedicationNotificationTexts()
        )
    }

    /// `MedicationReminderHandlerTest.kt:66-78`.
    @Test("emits dose occurrences with local-time triggers in the current zone")
    func emitsDoseOccurrencesWithLocalTimeTriggersInTheCurrentZone() async throws {
        let occurrences = try await handler.occurrencesBetween(
            from: Self.windowStart,
            until: Self.windowStart + 48 * Self.hour
        )

        #expect(occurrences.count == 2) // 08:00 on both window days
        let first = try #require(occurrences.first)
        #expect(first.entityId == "sch-1")
        #expect(first.occurrenceKey == DoseOccurrenceKey.encode(epochDay: Self.dayEpoch, minuteOfDay: 480))
        #expect(first.triggerAt == LocalDateTime(date: Self.day, minuteOfDay: 8 * 60).instant(in: Self.zone))
    }

    /// `MedicationReminderHandlerTest.kt:80-90`.
    @Test("taken doses are not emitted again")
    func takenDosesAreNotEmittedAgain() async throws {
        try await handler.onAction(ref: Self.doseRef, actionId: MedicationReminderHandler.actionTaken)

        let occurrences = try await handler.occurrencesBetween(
            from: Self.windowStart,
            until: Self.windowStart + 24 * Self.hour
        )

        #expect(occurrences.isEmpty)
    }

    /// `MedicationReminderHandlerTest.kt:92-113`.
    @Test("a silenced medication contributes no occurrences while its sibling still does")
    func aSilencedMedicationContributesNoOccurrencesWhileItsSiblingStillDoes() async throws {
        repository.setMedications([
            MedicationWithSchedules(
                medication: testMedication(id: "med-1", startDateEpochDay: 0, remindersEnabled: false),
                schedules: [testSchedule(id: "sch-1", medicationId: "med-1", timeOfDayMinutes: 8 * 60)]
            ),
            MedicationWithSchedules(
                medication: testMedication(id: "med-2", startDateEpochDay: 0),
                schedules: [testSchedule(id: "sch-2", medicationId: "med-2", timeOfDayMinutes: 9 * 60)]
            )
        ])

        let occurrences = try await handler.occurrencesBetween(
            from: Self.windowStart,
            until: Self.windowStart + 24 * Self.hour
        )

        #expect(occurrences.map(\.entityId) == ["sch-2"])
        #expect(try await handler.notificationContent(for: Self.doseRef) == nil)
    }

    /// `MedicationReminderHandlerTest.kt:115-123`.
    @Test("a re-enabled medication rings again")
    func aReEnabledMedicationRingsAgain() async throws {
        try await repository.setRemindersEnabled(medicationId: "med-1", enabled: false)
        #expect(try await handler.occurrencesBetween(
            from: Self.windowStart,
            until: Self.windowStart + 24 * Self.hour
        ).isEmpty)

        try await repository.setRemindersEnabled(medicationId: "med-1", enabled: true)

        #expect(try await handler.occurrencesBetween(
            from: Self.windowStart,
            until: Self.windowStart + 24 * Self.hour
        ).count == 1)
    }

    /// `MedicationReminderHandlerTest.kt:125-141`.
    @Test("snoozed dose is re-emitted with the snooze instant as trigger")
    func snoozedDoseIsReEmittedWithTheSnoozeInstantAsTrigger() async throws {
        try await handler.onAction(ref: Self.doseRef, actionId: MedicationReminderHandler.actionSnooze)

        let occurrences = try await handler.occurrencesBetween(
            from: Self.windowStart,
            until: Self.windowStart + 24 * Self.hour
        )

        #expect(occurrences.count == 1)
        let snoozed = try #require(occurrences.first)
        #expect(snoozed.occurrenceKey == DoseOccurrenceKey.encode(epochDay: Self.dayEpoch, minuteOfDay: 480))
        #expect(snoozed.triggerAt == clock.now() + SnoozeDoseUseCase.snoozeDuration)
        #expect(scheduler.syncRequests == 1)
    }

    /// `MedicationReminderHandlerTest.kt:143-155`.
    @Test("notification content includes name and both actions")
    func notificationContentIncludesNameAndBothActions() async throws {
        let content = try await handler.notificationContent(for: Self.doseRef)

        let unwrapped = try #require(content)
        #expect(unwrapped.title.contains("Aspirin"))
        #expect(unwrapped.actions.map(\.id) == [
            MedicationReminderHandler.actionTaken,
            MedicationReminderHandler.actionSnooze
        ])
    }

    /// `MedicationReminderHandlerTest.kt:157-164`.
    @Test("a dose is presented as an alarm, not a notification")
    func aDoseIsPresentedAsAnAlarmNotANotification() async throws {
        let content = try await handler.notificationContent(for: Self.doseRef)

        #expect(content?.presentation == .alarm)
    }

    /// `MedicationReminderHandlerTest.kt:166-183`.
    ///
    /// The snooze path inherits ALARM for free, and this test is what keeps that true: a snooze
    /// re-triggers the SAME MEDICATION_DOSE occurrence rather than materializing a reminder of
    /// its own, so it comes back through this handler and the presentation cannot drift apart.
    @Test("a snoozed dose is still presented as an alarm")
    func aSnoozedDoseIsStillPresentedAsAnAlarm() async throws {
        try await handler.onAction(ref: Self.doseRef, actionId: MedicationReminderHandler.actionSnooze)

        let occurrences = try await handler.occurrencesBetween(
            from: Self.windowStart,
            until: Self.windowStart + 24 * Self.hour
        )
        let snoozed = try #require(occurrences.first)
        #expect(occurrences.count == 1)
        let content = try await handler.notificationContent(
            for: ReminderRef(
                type: .medicationDose,
                entityId: snoozed.entityId,
                occurrenceKey: snoozed.occurrenceKey
            )
        )

        #expect(handler.type == .medicationDose)
        #expect(content?.presentation == .alarm)
    }

    /// `MedicationReminderHandlerTest.kt:185-201`.
    @Test("notification content is null for a deleted medication or taken dose")
    func notificationContentIsNullForADeletedMedicationOrTakenDose() async throws {
        try await handler.onAction(ref: Self.doseRef, actionId: MedicationReminderHandler.actionTaken)
        #expect(try await handler.notificationContent(for: Self.doseRef) == nil)

        try await repository.deleteMedication(id: "med-1")
        #expect(try await handler.notificationContent(
            for: ReminderRef(
                type: .medicationDose,
                entityId: "sch-1",
                occurrenceKey: DoseOccurrenceKey.encode(epochDay: Self.dayEpoch, minuteOfDay: 540)
            )
        ) == nil)
    }

    /// No Kotlin twin: Android's `when (actionId)` has no `else` branch, so the no-op is a
    /// property of the language rather than of a test. On iOS a `switch` over a `String` needs a
    /// `default`, and a `default` that did anything would resolve a dose the user only silenced —
    /// `ReminderActionIds/dismiss` is the engine's own action and leaves the occurrence unanswered.
    @Test("dismiss is a no-op and leaves the log untouched")
    func dismissIsANoOpAndLeavesTheLogUntouched() async throws {
        try await handler.onAction(ref: Self.doseRef, actionId: ReminderActionIds.dismiss)

        #expect(repository.logs.isEmpty)
        #expect(scheduler.syncRequests == 0)
        #expect(try await handler.occurrencesBetween(
            from: Self.windowStart,
            until: Self.windowStart + 24 * Self.hour
        ).count == 1)
    }

    /// No Kotlin twin: the Kotlin case asserts the two ids as a set of what is present, and the
    /// ORDER is what iOS depends on — AlarmKit's alert surface shows the first declared action as
    /// its only secondary button, so "taken" first is the difference between one tap and none.
    @Test("the first action is taken and the second is snooze")
    func theFirstActionIsTakenAndTheSecondIsSnooze() async throws {
        let content = try #require(try await handler.notificationContent(for: Self.doseRef))

        #expect(content.actions == [
            ReminderAction(id: "taken", label: "Taken"),
            ReminderAction(id: "snooze", label: "Snooze")
        ])
    }
}

/// The twin of Robolectric resolving `context.getString` against the real resources
/// (`MedicationReminderHandlerTest.kt:56, 60`), with the composition made visible so an assertion on
/// the rendered sentence describes the handler's choice rather than the catalog's copy.
private struct FakeMedicationNotificationTexts: MedicationNotificationTexts {
    func doseTitle(medicationName: String) -> String {
        "Time for \(medicationName)"
    }

    func doseText(amount: String, strength: String) -> String {
        "Take \(amount) x \(strength)"
    }

    func doseTextPlain(amount: String) -> String {
        "Take \(amount) dose(s)"
    }

    var actionTaken: String { "Taken" }
    var actionSnooze: String { "Snooze" }
}
