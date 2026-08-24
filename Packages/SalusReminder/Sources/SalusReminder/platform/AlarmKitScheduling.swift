// The alarm backend: spec's 2026-08-23 AlarmKit note, case 1 (iOS 26+).
//
// A `ReminderPresentation.alarm` occurrence is a medication dose, and a dose that arrives as an
// ordinary notification is a dose the user does not take. AlarmKit gives it what Android gets from
// a full-screen intent on the alarm stream: full-screen presentation, sound through silent mode and
// Focus, no Apple entitlement or review gate — runtime authorization plus
// `NSAlarmKitUsageDescription`. Alarms scheduled this way are NOT pending notifications, so they do
// not spend the 64-slot budget §6.1's window math is written against.
//
// Two things are deliberately absent, both because they cannot be proven here:
//
//  * The whole framework half is behind `#if canImport(AlarmKit)`. AlarmKit is iOS-only, and
//    `swift test` builds this package for macOS, where the module does not exist. The seam and its
//    identity math are outside the guard and ARE tested; the adapter compiles in the iOS build and
//    its real behaviour is validated on device in iOS-M5 (the plan's M3a).
//  * The alarm's buttons are the system's. `AlarmPresentation.Alert` has a default stop button that
//    iOS localizes itself, and a custom secondary button would need an `AppIntents`
//    `LiveActivityIntent` — a fire-time hook this milestone does not have. The handler's actions
//    still reach the user on the fallback path (they are notification actions there); wiring them
//    into the alarm surface is iOS-M5's, together with the on-device validation.

import Foundation

/// Scheduling a dose as a real system alarm.
///
/// Mirrors ``NotificationGateway``'s three verbs, minus the parts only notifications have. The
/// gateway holds one OPTIONALLY: its presence is what "this device can ring an alarm" means, so a
/// routing test says iOS 26 by injecting a double instead of faking an availability check.
public protocol AlarmKitScheduling: Sendable {
    /// Adds — or replaces — the alarm for `requestCode`.
    func schedule(
        requestCode: Int32,
        triggerAt: Date,
        content: ReminderNotificationContent,
        ref: ReminderRef
    ) async throws

    /// Drops every listed alarm. Codes the manager does not hold are ignored, not an error.
    func cancel(requestCodes: [Int32]) async

    /// What the alarm manager is holding right now.
    func scheduledRequestCodes() async -> Set<Int32>
}

/// AlarmKit's runtime authorization, which is the whole gate on the alarm path: there is no Apple
/// entitlement and no review application, only this prompt plus `NSAlarmKitUsageDescription`.
///
/// Split from ``AlarmKitScheduling`` because the two have different callers and different rules.
/// The gateway schedules and never asks; Reminder Health (iOS-M3 Task 8) asks and never schedules.
/// A device below iOS 26.1 has neither, and both seams say so the same way — by being absent.
public protocol AlarmKitAuthorizing: Sendable {
    /// Whether alarms may take over the screen right now.
    func isAuthorized() async -> Bool

    /// Shows the AlarmKit prompt if it has not been shown, and reports the resulting state.
    func requestAuthorization() async -> Bool
}

/// The bridge between the ledger's request code and AlarmKit's `UUID` alarm id.
///
/// AlarmKit is addressed by `UUID`, the ledger by `Int32`, and cancellation is handed only the
/// latter — after the process that scheduled the alarm has died. So the id is DERIVED from the
/// code rather than stored next to it, the same bargain the request code itself strikes with the
/// occurrence identity (`ReminderWindowSynchronizer.requestCode`).
public enum ReminderAlarmIdentity {
    /// The first twelve bytes, fixed. They make an id recognisably the reminder engine's, so an
    /// alarm some other part of the app scheduled is not mistaken for one of ours — and they leave
    /// the last four to carry the request code.
    private static let prefix: [UInt8] = [
        0x5A, 0x41, 0x4C, 0x55, 0x53, 0x52, 0x4D, 0x44, 0x0A, 0x1A, 0x00, 0x00
    ]

    /// The alarm id for one occurrence.
    public static func alarmId(for requestCode: Int32) -> UUID {
        let code = UInt32(bitPattern: requestCode)
        let bytes = prefix + [
            UInt8(truncatingIfNeeded: code >> 24),
            UInt8(truncatingIfNeeded: code >> 16),
            UInt8(truncatingIfNeeded: code >> 8),
            UInt8(truncatingIfNeeded: code)
        ]
        return UUID(uuid: (
            bytes[0], bytes[1], bytes[2], bytes[3],
            bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11],
            bytes[12], bytes[13], bytes[14], bytes[15]
        ))
    }

    /// The request code inside one of our alarm ids, or nil for an id we did not mint.
    public static func requestCode(of alarmId: UUID) -> Int32? {
        let bytes = withUnsafeBytes(of: alarmId.uuid) { Array($0) }
        guard Array(bytes.prefix(prefix.count)) == prefix else { return nil }

        let code = bytes.suffix(4).reduce(UInt32(0)) { accumulated, byte in
            accumulated << 8 | UInt32(byte)
        }
        return Int32(bitPattern: code)
    }
}

#if canImport(AlarmKit)

    import ActivityKit
    import AlarmKit
    import SwiftUI

    /// The occurrence identity, carried on the alarm the way ``ReminderUserInfo`` carries it on a
    /// notification: it is how a stopped alarm says which dose it was.
    @available(iOS 26.0, *)
    public struct ReminderAlarmMetadata: AlarmMetadata {
        public let type: String
        public let entityId: String
        public let occurrenceKey: String

        public init(ref: ReminderRef) {
            type = ref.type.rawValue
            entityId = ref.entityId
            occurrenceKey = ref.occurrenceKey
        }
    }

    /// The real AlarmKit manager.
    ///
    /// Stateless by construction, for the same reason ``SystemUserNotificationCenter`` is:
    /// `AlarmManager.shared` is resolved per call rather than stored, which is what lets this be a
    /// `Sendable` struct over a class that is not.
    ///
    /// **iOS 26.1, not 26.0**, and the half-version is deliberate. Apple changed the alarm alert's
    /// buttons in 26.1: `AlarmPresentation.Alert` gained an initializer that omits the stop button
    /// — iOS supplies and localizes it — and deprecated the one that demands it. On 26.0 the only
    /// initializer available takes an app-supplied `AlarmButton`, i.e. a piece of user-facing copy
    /// this package has no string catalog for and would have to invent in two languages for a
    /// version window that closed in October 2025. A 26.0 device therefore takes the same
    /// time-sensitive fallback iOS 17-25 do, which the spec's AlarmKit note already describes as an
    /// accepted degradation. Nothing else in the engine version-checks: the composition root builds
    /// this behind `#available` and the gateway routes on whether it got one.
    @available(iOS 26.1, *)
    public struct SystemAlarmKitScheduler: AlarmKitScheduling, AlarmKitAuthorizing {
        public init() {}

        public func isAuthorized() async -> Bool {
            AlarmManager.shared.authorizationState == .authorized
        }

        public func requestAuthorization() async -> Bool {
            // Throws when the prompt cannot be shown at all — no usage description, or a request
            // already in flight. Neither is authorization, and neither is recoverable here:
            // Reminder Health's row simply keeps reading "not authorized".
            let state = try? await AlarmManager.shared.requestAuthorization()
            return state == .authorized
        }

        public func schedule(
            requestCode: Int32,
            triggerAt: Date,
            content: ReminderNotificationContent,
            ref: ReminderRef
        ) async throws {
            // `content.title` is a runtime string the handler already localized; wrapping it as a
            // `LocalizedStringResource` looks it up, misses, and falls back to the string itself,
            // which is the intended result. AlarmKit takes nothing else.
            let alert = AlarmPresentation.Alert(title: LocalizedStringResource(stringLiteral: content.title))
            let attributes = AlarmAttributes(
                presentation: AlarmPresentation(alert: alert),
                metadata: ReminderAlarmMetadata(ref: ref),
                tintColor: Color.accentColor
            )
            let configuration = AlarmManager.AlarmConfiguration.alarm(
                schedule: .fixed(triggerAt),
                attributes: attributes,
                sound: .named(ReminderAlarmSound.fileName)
            )

            _ = try await AlarmManager.shared.schedule(
                id: ReminderAlarmIdentity.alarmId(for: requestCode),
                configuration: configuration
            )
        }

        public func cancel(requestCodes: [Int32]) async {
            for code in requestCodes {
                // Cancelling an alarm the manager does not hold throws; the batch is built from the
                // ledger, which can be ahead of reality, so that is expected rather than an error.
                try? AlarmManager.shared.cancel(id: ReminderAlarmIdentity.alarmId(for: code))
            }
        }

        public func scheduledRequestCodes() async -> Set<Int32> {
            let alarms = (try? AlarmManager.shared.alarms) ?? []
            return Set(alarms.compactMap { ReminderAlarmIdentity.requestCode(of: $0.id) })
        }
    }

#endif
