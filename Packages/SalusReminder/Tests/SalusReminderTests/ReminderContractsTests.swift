import Foundation
import SalusModel
import Testing

@testable import SalusReminder

/// A handler that answers from canned values, so a registry test never needs a real feature.
private struct StubHandler: ReminderHandler {
    let type: ReminderType
    var name = ""

    func occurrencesBetween(from _: Date, until _: Date) async throws -> [ReminderOccurrence] {
        []
    }

    func notificationContent(for _: ReminderRef) async throws -> ReminderNotificationContent? {
        nil
    }
}

@Suite("Reminder contracts")
struct ReminderContractsTests {
    // MARK: - Raw-value pins

    @Test("presentation raw values are the Kotlin constant names")
    func presentationRawValuesArePinned() {
        #expect(ReminderPresentation.notification.rawValue == "NOTIFICATION")
        #expect(ReminderPresentation.alarm.rawValue == "ALARM")
    }

    @Test("presentation round-trips through its raw value")
    func presentationRoundTripsThroughRawValue() {
        #expect(ReminderPresentation(rawValue: "NOTIFICATION") == .notification)
        #expect(ReminderPresentation(rawValue: "ALARM") == .alarm)
        #expect(ReminderPresentation(rawValue: "notification") == nil)
    }

    @Test("the engine-owned dismiss action id is pinned")
    func dismissActionIdIsPinned() {
        #expect(ReminderActionIds.dismiss == "dismiss")
    }

    // MARK: - Defaults

    @Test("content defaults to a plain notification with no actions")
    func contentDefaultsToPlainNotification() {
        let content = ReminderNotificationContent(title: "Doz", text: "08:00")

        #expect(content.presentation == .notification)
        #expect(content.actions.isEmpty)
    }

    @Test("content keeps an explicitly requested alarm presentation")
    func contentKeepsExplicitAlarmPresentation() {
        let content = ReminderNotificationContent(
            title: "Doz",
            text: "08:00",
            actions: [ReminderAction(id: "taken", label: "Alındı")],
            presentation: .alarm
        )

        #expect(content.presentation == .alarm)
        #expect(content.actions == [ReminderAction(id: "taken", label: "Alındı")])
    }

    // MARK: - ReminderRef identity

    @Test("refs with the same three fields are equal and hash alike")
    func equalRefsHashAlike() {
        let one = ReminderRef(type: .medicationDose, entityId: "m1", occurrenceKey: "2026-09-01T08:00")
        let other = ReminderRef(type: .medicationDose, entityId: "m1", occurrenceKey: "2026-09-01T08:00")

        #expect(one == other)
        #expect(one.hashValue == other.hashValue)
        #expect(Set([one, other]).count == 1)
    }

    @Test("each field separates one ref from another")
    func everyFieldParticipatesInIdentity() {
        let base = ReminderRef(type: .medicationDose, entityId: "m1", occurrenceKey: "2026-09-01T08:00")
        let otherType = ReminderRef(type: .appointment, entityId: "m1", occurrenceKey: "2026-09-01T08:00")
        let otherEntity = ReminderRef(type: .medicationDose, entityId: "m2", occurrenceKey: "2026-09-01T08:00")
        let otherKey = ReminderRef(type: .medicationDose, entityId: "m1", occurrenceKey: "2026-09-01T20:00")

        #expect(base != otherType)
        #expect(base != otherEntity)
        #expect(base != otherKey)
        #expect(Set([base, otherType, otherEntity, otherKey]).count == 4)
    }

    // MARK: - Handler defaults

    @Test("onAction defaults to doing nothing")
    func onActionDefaultsToNoOp() async throws {
        let handler = StubHandler(type: .cyclePeriod)
        let ref = ReminderRef(type: .cyclePeriod, entityId: "c1", occurrenceKey: "2026-09-01")

        try await handler.onAction(ref: ref, actionId: ReminderActionIds.dismiss)
    }
}

@Suite("Reminder handler registry")
struct ReminderHandlerRegistryTests {
    private let registry = ReminderHandlerRegistry(all: [
        StubHandler(type: .medicationDose),
        StubHandler(type: .appointment)
    ])

    @Test("all keeps the handlers it was built with, in order")
    func allKeepsTheGivenHandlers() {
        #expect(registry.all.map(\.type) == [.medicationDose, .appointment])
    }

    @Test("a handler is found by its type")
    func handlerIsFoundByType() {
        #expect(registry.forType(.medicationDose)?.type == .medicationDose)
        #expect(registry.forType(.appointment)?.type == .appointment)
        #expect(registry.forType(.cyclePeriod) == nil)
    }

    @Test("a handler is found by the persisted type name")
    func handlerIsFoundByTypeName() {
        #expect(registry.forType(typeName: "MEDICATION_DOSE")?.type == .medicationDose)
        #expect(registry.forType(typeName: "CYCLE_PERIOD") == nil)
        #expect(registry.forType(typeName: "NOT_A_TYPE") == nil)
    }

    @Test("a duplicate type is won by the last handler, as Kotlin's associateBy does")
    func duplicateTypeIsWonByTheLastHandler() {
        let duplicated = ReminderHandlerRegistry(all: [
            StubHandler(type: .medicationDose, name: "first"),
            StubHandler(type: .medicationDose, name: "last")
        ])

        #expect(duplicated.all.count == 2)
        #expect((duplicated.forType(.medicationDose) as? StubHandler)?.name == "last")
    }

    @Test("an empty registry answers nothing")
    func emptyRegistryAnswersNothing() {
        let empty = ReminderHandlerRegistry(all: [])

        #expect(empty.all.isEmpty)
        #expect(empty.forType(.medicationDose) == nil)
    }
}
