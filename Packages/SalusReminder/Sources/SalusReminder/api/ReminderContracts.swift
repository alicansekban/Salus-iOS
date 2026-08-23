// Ported 1:1 from Android
// `core/reminder/src/main/kotlin/com/alicansekban/salus/core/reminder/api/ReminderContracts.kt`,
// with `ReminderEnvironment` re-read for iOS (see its doc comment).
//
// PURE SWIFT contracts between the reminder engine and the features. On Android the same
// contracts are fulfilled by an AlarmManager-backed engine, so nothing in this file may import
// UserNotifications, AlarmKit, SwiftUI or UIKit — `Foundation` for `Date` is the whole budget.

import Foundation
import SalusModel

/// Identity of one materialized reminder occurrence.
public struct ReminderRef: Hashable, Sendable {
    public let type: ReminderType
    public let entityId: String
    public let occurrenceKey: String

    public init(type: ReminderType, entityId: String, occurrenceKey: String) {
        self.type = type
        self.entityId = entityId
        self.occurrenceKey = occurrenceKey
    }
}

/// One trigger a handler asks the engine to materialize.
public struct ReminderOccurrence: Equatable, Sendable {
    public let entityId: String
    /// Stable, deterministic identity within the entity, e.g. "2026-09-01T08:00".
    public let occurrenceKey: String
    public let triggerAt: Date

    public init(entityId: String, occurrenceKey: String, triggerAt: Date) {
        self.entityId = entityId
        self.occurrenceKey = occurrenceKey
        self.triggerAt = triggerAt
    }
}

/// One tappable action on a fired reminder.
public struct ReminderAction: Equatable, Sendable {
    public let id: String
    public let label: String

    public init(id: String, label: String) {
        self.id = id
        self.label = label
    }
}

/// Action ids the ENGINE owns, as opposed to the feature-specific ones a handler declares.
public enum ReminderActionIds {
    /// Silences a fired reminder without resolving what it was about. Handlers deliberately
    /// do not implement it: the engine's own reaction — cancel the notification, stop the
    /// alarm — is the whole behaviour, and the occurrence stays unresolved.
    public static let dismiss = "dismiss"
}

/// How urgently a fired occurrence must reach the user. Decided by the HANDLER, never by the
/// presenter: only the feature knows whether a missed occurrence is a health event. A
/// medication dose is ``alarm``; appointment and cycle reminders fire with lead time and stay
/// ``notification``.
///
/// Raw values are the Kotlin constant names, so both platforms name the same decision.
public enum ReminderPresentation: String, Sendable {
    /// Ordinary heads-up notification on the shared reminders channel.
    case notification = "NOTIFICATION"

    /// Full-screen alarm over the lock screen, alarm-stream sound, looped until answered.
    case alarm = "ALARM"
}

/// What a fired occurrence says, baked by its handler at sync time.
public struct ReminderNotificationContent: Equatable, Sendable {
    public let title: String
    public let text: String
    public var actions: [ReminderAction] = []
    public var presentation: ReminderPresentation = .notification

    public init(
        title: String,
        text: String,
        actions: [ReminderAction] = [],
        presentation: ReminderPresentation = .notification
    ) {
        self.title = title
        self.text = text
        self.actions = actions
        self.presentation = presentation
    }
}

/// Implemented by each feature that owns reminders (medications, appointments, cycle) and
/// handed to the composition root, which collects them into a ``ReminderHandlerRegistry``.
/// The registry is the twin of Koin's `getAll()`.
public protocol ReminderHandler: Sendable {
    var type: ReminderType { get }

    /// All occurrences whose trigger falls in [from, until), computed from the feature's own
    /// source of truth. Local-time semantics (DST!) are the handler's responsibility: convert
    /// minuteOfDay/epochDay to a `Date` with the CURRENT time zone at call time.
    func occurrencesBetween(from: Date, until: Date) async throws -> [ReminderOccurrence]

    /// Notification content for a fired occurrence, or nil if it is no longer relevant.
    func notificationContent(for ref: ReminderRef) async throws -> ReminderNotificationContent?

    /// Reaction to a notification action tap (e.g. TAKEN, SNOOZE). Runs off the main actor.
    func onAction(ref: ReminderRef, actionId: String) async throws
}

extension ReminderHandler {
    /// Kotlin's `onAction` has an empty body, so a handler with nothing to react to says nothing.
    public func onAction(ref _: ReminderRef, actionId _: String) async throws {}
}

/// Features call this after any change that affects upcoming reminders.
public protocol ReminderScheduler: Sendable {
    /// Enqueues a unique background sync of the alarm window (safe to call often).
    func requestSync()
}

/// Read-only view of the device state the reminder pipeline depends on.
///
/// The iOS re-reading of Android's three questions: exact-alarm and battery-optimization
/// permissions have no iOS twin, and what replaces them is the notification authorization,
/// AlarmKit's own authorization, and whether background refresh can run a sync at all.
public protocol ReminderEnvironment: Sendable {
    /// Whether the user has authorized notifications. False means every reminder is silent —
    /// nothing is scheduled that the user would ever see.
    func notificationsAuthorized() async -> Bool

    /// Whether a ``ReminderPresentation/alarm`` occurrence may take over the screen through
    /// AlarmKit. Always false below iOS 26, where AlarmKit does not exist; a dose still posts
    /// (time-sensitive, with the alarm sound) without it, so this reports a degraded state,
    /// never a dead reminder.
    func alarmKitAuthorized() async -> Bool

    /// Whether the OS will run the background sync that refills the alarm window. False means
    /// the window is only refilled while the app is open.
    func backgroundRefreshAvailable() -> Bool
}
