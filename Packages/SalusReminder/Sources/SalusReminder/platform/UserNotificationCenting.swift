// The seam over `UNUserNotificationCenter`.
//
// It exists for one reason: `UNUserNotificationCenter.current()` cannot be constructed, replaced
// or observed in a unit test, and on the `swift test` host (macOS, no app bundle) merely touching
// it traps. Everything this package does with notifications therefore goes through this protocol,
// and the tests inject a fake that records the REAL `UNNotificationRequest` objects — so a pin on
// the identifier, the userInfo or the interruption level is a pin on what iOS would receive.
//
// Android needs no twin: `AndroidAlarmGateway` talks to `AlarmManager`, whose alarms carry no
// content and cannot be enumerated, so its tests had nothing to record.
//
// This file and its two siblings are the ONLY places in `SalusReminder` that import
// UserNotifications; `api/` and `engine/` stay framework-free (the plan's domain-purity constraint).

import Foundation
import UserNotifications

/// Everything the reminder engine asks of the notification centre.
///
/// The members are the `UNUserNotificationCenter` ones they wrap, spelled `async` throughout:
/// `setNotificationCategories` and `removePendingNotificationRequests` are synchronous on the real
/// centre, and are `async` here so an implementation is free to hop (the system one does not, the
/// fake does not either — the uniformity is for the call sites).
public protocol UserNotificationCenting: Sendable {
    /// Adds — or, under an identifier the centre already holds, replaces — one request.
    func add(_ request: UNNotificationRequest) async throws

    func removePendingNotificationRequests(withIdentifiers identifiers: [String]) async

    func pendingNotificationRequests() async -> [UNNotificationRequest]

    /// The authorization and presentation settings, or nil when they cannot be read.
    ///
    /// The optional is not defensive: `UNNotificationSettings` has no public initializer, so no
    /// test double can produce one, and a seam that promised a non-optional would be a seam no
    /// fake could implement. Callers read nil as "unknown" — which is also the honest answer off
    /// device. Reminder Health (Task 8) is the one screen that shows it.
    func notificationSettings() async -> UNNotificationSettings?

    /// Replaces the whole registered set — the centre keeps only the latest one.
    func setNotificationCategories(_ categories: Set<UNNotificationCategory>) async

    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool
}

/// The real centre.
///
/// Stateless by construction: `UNUserNotificationCenter.current()` is resolved per call rather than
/// stored, which is what lets this be a `Sendable` struct over a class that is not.
public struct SystemUserNotificationCenter: UserNotificationCenting {
    public init() {}

    public func add(_ request: UNNotificationRequest) async throws {
        try await UNUserNotificationCenter.current().add(request)
    }

    public func removePendingNotificationRequests(withIdentifiers identifiers: [String]) async {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    public func pendingNotificationRequests() async -> [UNNotificationRequest] {
        await UNUserNotificationCenter.current().pendingNotificationRequests()
    }

    public func notificationSettings() async -> UNNotificationSettings? {
        await UNUserNotificationCenter.current().notificationSettings()
    }

    public func setNotificationCategories(_ categories: Set<UNNotificationCategory>) async {
        UNUserNotificationCenter.current().setNotificationCategories(categories)
    }

    public func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool {
        try await UNUserNotificationCenter.current().requestAuthorization(options: options)
    }
}
