// What the gateway hands the OS, pinned against the real framework objects: the identifier, the
// identity extras, the category, the trigger.
//
// Every case here asserts on a `UNNotificationRequest` the fake centre actually received, because
// those fields are the whole contract between this package and iOS. Nothing of ours runs when a
// reminder fires; the request IS the behaviour, so a test that asserted on a paraphrase of it would
// prove nothing.
//
// The presentation routing — the `.alarm` fork, cancellation across both backends and the pending
// budget — is the sibling `UserNotificationGatewayRoutingTests`; both share `GatewayFixture`.

import Foundation
import SalusModel
import Testing
import UserNotifications

@testable import SalusReminder

@Suite("UserNotificationGateway request shape")
struct UserNotificationGatewayTests {
    private let fixture = GatewayFixture()

    // MARK: - Identity

    /// The identifier is the ledger's request code and nothing else: it is what `cancel` is given
    /// after the process that scheduled the request has died, so it has to be recomputable rather
    /// than remembered. Negative codes are ordinary — the code is a Java string hash.
    @Test("the request identifier is the request code, verbatim", arguments: [Int32(0), 42, -1_234_567_890])
    func identifierIsTheRequestCode(code: Int32) async throws {
        try await fixture.gateway().schedule(
            requestCode: code,
            triggerAt: GatewayFixture.triggerAt,
            content: fixture.content(),
            ref: fixture.ref()
        )

        #expect(fixture.center.pending.map(\.identifier) == [String(code)])
    }

    /// Re-scheduling the same occurrence replaces rather than duplicates — the property the
    /// synchronizer's "re-schedule everything, every pass" strategy rests on.
    @Test("scheduling the same request code twice replaces the request")
    func schedulingTwiceReplaces() async throws {
        let gateway = fixture.gateway()

        try await gateway.schedule(
            requestCode: 7,
            triggerAt: GatewayFixture.triggerAt,
            content: fixture.content(title: "old"),
            ref: fixture.ref()
        )
        try await gateway.schedule(
            requestCode: 7,
            triggerAt: GatewayFixture.triggerAt,
            content: fixture.content(title: "new"),
            ref: fixture.ref()
        )

        #expect(fixture.center.pending.count == 1)
        #expect(fixture.center.pending.first?.content.title == "new")
    }

    /// The `ReminderIntentExtras` twin. These three values are the only way a tapped notification
    /// says which occurrence it was, so their KEYS are as load-bearing as the request code.
    @Test("userInfo carries the reminder ref under the Android-verbatim keys")
    func userInfoCarriesTheRef() async throws {
        let ref = fixture.ref(.appointment, "appt-9", "2026-10-02T09:30")

        try await fixture.gateway().schedule(
            requestCode: 11,
            triggerAt: GatewayFixture.triggerAt,
            content: fixture.content(),
            ref: ref
        )

        let userInfo = try #require(fixture.center.pending.first?.content.userInfo)
        #expect(userInfo[ReminderUserInfo.type] as? String == "APPOINTMENT")
        #expect(userInfo[ReminderUserInfo.entityId] as? String == "appt-9")
        #expect(userInfo[ReminderUserInfo.occurrenceKey] as? String == "2026-10-02T09:30")
    }

    /// Pins the key strings against `ReminderIntentExtras`
    /// (`ReminderNotificationPresenter.kt:13-17`). A rename here is invisible at compile time and
    /// strands every request already scheduled under the old keys.
    @Test("the userInfo keys are the Kotlin extras, verbatim")
    func userInfoKeysAreTheKotlinExtras() {
        #expect(ReminderUserInfo.type == "salus.extra.REMINDER_TYPE")
        #expect(ReminderUserInfo.entityId == "salus.extra.REMINDER_ENTITY_ID")
        #expect(ReminderUserInfo.occurrenceKey == "salus.extra.REMINDER_OCCURRENCE_KEY")
    }

    // MARK: - Content and actions

    /// Title and body are baked at sync time — there is no fire-time hook on iOS to build them in.
    @Test("title and text are baked into the request")
    func titleAndTextAreBaked() async throws {
        try await fixture.gateway().schedule(
            requestCode: 3,
            triggerAt: GatewayFixture.triggerAt,
            content: fixture.content(title: "Metformin", text: "1 tablet"),
            ref: fixture.ref()
        )

        let content = try #require(fixture.center.pending.first?.content)
        #expect(content.title == "Metformin")
        #expect(content.body == "1 tablet")
    }

    /// Actions reach the OS as a category registered per `ReminderType`, carrying the handler's own
    /// ids and labels in order. The request points at that category by identifier.
    @Test("actions become one category per reminder type, keyed by the handler's action ids")
    func actionsBecomeACategoryPerType() async throws {
        let content = fixture.content(
            title: "Metformin",
            text: "1 tablet",
            actions: [
                ReminderAction(id: "TAKEN", label: "Aldım"),
                ReminderAction(id: "SNOOZE", label: "Ertele")
            ]
        )

        try await fixture.gateway().schedule(
            requestCode: 5,
            triggerAt: GatewayFixture.triggerAt,
            content: content,
            ref: fixture.ref()
        )

        let expectedIdentifier = ReminderNotificationCategories.identifier(for: .medicationDose)
        #expect(fixture.center.pending.first?.content.categoryIdentifier == expectedIdentifier)

        let category = try #require(
            fixture.center.registeredCategories.first { $0.identifier == expectedIdentifier }
        )
        #expect(category.actions.map(\.identifier) == ["TAKEN", "SNOOZE"])
        #expect(category.actions.map(\.title) == ["Aldım", "Ertele"])
        // A swipe-away is how a user silences a reminder without answering it, and
        // `ReminderActionIds.dismiss` is the engine's reaction to it. iOS delivers that only to a
        // category that asked for it.
        #expect(category.options.contains(.customDismissAction))
    }

    /// Actions are answered without showing UI, the way Android answers them in a BroadcastReceiver.
    @Test("actions are background actions, not app-opening ones")
    func actionsAreBackgroundActions() async throws {
        try await fixture.gateway().schedule(
            requestCode: 6,
            triggerAt: GatewayFixture.triggerAt,
            content: fixture.content(actions: [ReminderAction(id: "TAKEN", label: "Aldım")]),
            ref: fixture.ref()
        )

        let category = try #require(fixture.center.registeredCategories.first)
        #expect(category.actions.first?.options.contains(.foreground) == false)
    }

    /// One category per type, and the whole set is re-registered on every change — the centre keeps
    /// only the latest set, so a partial registration would silently drop the other types' actions.
    @Test("categories for different reminder types accumulate rather than replace each other")
    func categoriesAccumulateAcrossTypes() async throws {
        let gateway = fixture.gateway()

        try await gateway.schedule(
            requestCode: 1,
            triggerAt: GatewayFixture.triggerAt,
            content: fixture.content(actions: [ReminderAction(id: "TAKEN", label: "Aldım")]),
            ref: fixture.ref(.medicationDose)
        )
        try await gateway.schedule(
            requestCode: 2,
            triggerAt: GatewayFixture.triggerAt,
            content: fixture.content(actions: [ReminderAction(id: "OPEN", label: "Aç")]),
            ref: fixture.ref(.appointment, "appt-1")
        )

        let identifiers = Set(fixture.center.registeredCategories.map(\.identifier))
        #expect(identifiers == [
            ReminderNotificationCategories.identifier(for: .medicationDose),
            ReminderNotificationCategories.identifier(for: .appointment)
        ])
    }

    /// The category identifier is a stable, type-derived string; it ends up inside every scheduled
    /// request, so it survives launches the same way the request code does.
    @Test("the category identifier is derived from the reminder type")
    func categoryIdentifierIsDerivedFromTheType() {
        #expect(ReminderNotificationCategories.identifier(for: .medicationDose) == "salus.reminder.MEDICATION_DOSE")
        #expect(ReminderNotificationCategories.identifier(for: .appointment) == "salus.reminder.APPOINTMENT")
        #expect(ReminderNotificationCategories.identifier(for: .cyclePeriod) == "salus.reminder.CYCLE_PERIOD")
    }

    // MARK: - Trigger

    /// A calendar trigger in the CURRENT zone, never repeating: the occurrence's instant decomposed
    /// into the wall-clock components the OS API takes.
    @Test("the trigger is a non-repeating calendar trigger at the occurrence instant")
    func triggerIsANonRepeatingCalendarTrigger() async throws {
        try await fixture.gateway().schedule(
            requestCode: 9,
            triggerAt: GatewayFixture.triggerAt,
            content: fixture.content(),
            ref: fixture.ref()
        )

        let trigger = try #require(fixture.center.pending.first?.trigger as? UNCalendarNotificationTrigger)
        #expect(trigger.repeats == false)

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let expected = calendar.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: GatewayFixture.triggerAt
        )
        #expect(trigger.dateComponents.year == expected.year)
        #expect(trigger.dateComponents.month == expected.month)
        #expect(trigger.dateComponents.day == expected.day)
        #expect(trigger.dateComponents.hour == expected.hour)
        #expect(trigger.dateComponents.minute == expected.minute)
        #expect(trigger.dateComponents.second == expected.second)
    }
}
