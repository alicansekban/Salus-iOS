// The alarm backend: spec's 2026-08-23 AlarmKit note, case 1 (iOS 26+).
//
// A `ReminderPresentation.alarm` occurrence is a medication dose, and a dose that arrives as an
// ordinary notification is a dose the user does not take. AlarmKit gives it what Android gets from
// a full-screen intent on the alarm stream: full-screen presentation, sound through silent mode and
// Focus, no Apple entitlement or review gate — runtime authorization plus
// `NSAlarmKitUsageDescription`. Alarms scheduled this way are NOT pending notifications, so they do
// not spend the 64-slot budget §6.1's window math is written against.
//
// One thing is deliberately absent, because it cannot be proven here: the whole framework half is
// behind `#if canImport(AlarmKit)`. AlarmKit is iOS-only, and `swift test` builds this package for
// macOS, where the module does not exist. The seam and its identity math are outside the guard and
// ARE tested; the adapter compiles in the iOS build and its real behaviour is validated on device
// in iOS-M5 (the plan's M3a).
//
// The second absence — the alarm's buttons — is PAID as of iOS-M5. iOS-M3 shipped an alarm that
// rang and could not be answered: `schedule` dropped `content.actions`, and a dose whose only
// answer is "open the app and find it" is a dose that goes unrecorded. What was missing was the
// fire-time hook, an `AppIntents` `LiveActivityIntent`; ``AlarmActionIntentProvider`` is the seam
// the app target now fulfils, and the mapping onto the two buttons AlarmKit gives an alert is
// ``SystemAlarmKitScheduler/schedule(requestCode:triggerAt:content:ref:)``'s doc comment.

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
/// A device below iOS 26.0 has neither — `SystemAlarmKitScheduler` is `@available(iOS 26.0, *)` —
/// and both seams say so the same way, by being absent. The 26.1 line is about the alert's stop
/// button only: iOS supplies it from 26.1 up, the app supplies "Kapat" on 26.0.
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
    import AppIntents
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
    /// **iOS 26.0, and it used to be 26.1.** Apple changed the alarm alert's buttons in 26.1:
    /// `AlarmPresentation.Alert` gained an initializer that omits the stop button — iOS supplies
    /// and localizes it — and deprecated the one that demands it. iOS-M3 shipped the 26.1 gate
    /// because on 26.0 the only initializer available takes an app-supplied `AlarmButton`, i.e. a
    /// piece of user-facing copy this package had no string catalog for. It has one now
    /// (``ReminderStrings/alarmDismiss``, the twin of the label Android's `AlarmService.kt:87`
    /// appends), so the reason is spent and a 26.0 device rings a real alarm instead of taking the
    /// time-sensitive fallback iOS 17-25 do. The one branch that survives is which of the two
    /// initializers builds the alert, in ``schedule(requestCode:triggerAt:content:ref:)``.
    ///
    /// Nothing else in the engine version-checks: the composition root builds this behind
    /// `#available` and the gateway routes on whether it got one.
    @available(iOS 26.0, *)
    public struct SystemAlarmKitScheduler: AlarmKitScheduling, AlarmKitAuthorizing {
        private let intents: (any AlarmActionIntentProvider)?
        private let dismissLabel: String
        private let tintColor: Color

        /// - Parameters:
        ///   - intents: mints the `AppIntents` the alert's buttons run. Optional because the
        ///     concrete provider is the app target's — it is an `AppIntent`, whose metadata is
        ///     extracted at app build time — and a package that shipped a stand-in would be
        ///     shipping a button that does nothing. Without one the alarm still rings and still
        ///     stops; it just carries no answer, which is iOS-M3's behaviour exactly.
        ///   - dismissLabel: the stop button's copy on iOS 26.0. Ignored from 26.1 up, where the
        ///     system supplies and localizes that button itself.
        ///   - tintColor: the alert's accent, which AlarmKit paints its buttons with. Injected
        ///     rather than read from the environment because this type is a background scheduler,
        ///     not a view: it runs from a sync with no SwiftUI environment around it, so the one
        ///     place that can resolve the theme is the composition root. Android's twin colours the
        ///     same buttons with the *medications* feature accent (`AlarmScreen.kt:143-150`, whose
        ///     `SalusPillButton(accent = MaterialTheme.salusColors.medications)` fills the
        ///     un-tonal button with `accent.accent`), so that is the value to hand in — not
        ///     `Color.accentColor`, which this app has no asset for and which therefore resolved
        ///     to the system blue until iOS-M5's post-QA fix.
        public init(
            intents: (any AlarmActionIntentProvider)? = nil,
            dismissLabel: String = ReminderStrings.alarmDismiss,
            tintColor: Color
        ) {
            self.intents = intents
            self.dismissLabel = dismissLabel
            self.tintColor = tintColor
        }

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

        /// An alert has exactly two buttons, and this is what the engine's answers map onto.
        ///
        /// **Stop** is mandatory and is ``ReminderActionIds/dismiss``: the noise ends and the
        /// occurrence stays unresolved, which is the only safe reading of a button the OS may draw
        /// in its own words. It is never mapped to the handler's first action — a user silencing an
        /// alarm must not be recorded as having taken a dose.
        ///
        /// **Secondary** is optional and is `content.actions.first`, the answer that resolves the
        /// occurrence (`AlarmScreen.kt:144` draws it as the primary, un-tonal one). It is
        /// drawn only when there is an intent behind it, and `secondaryButtonBehavior: .custom` is
        /// what makes pressing it run that intent and end the alert rather than start a countdown.
        ///
        /// Three things Android's alarm surface has do not survive the mapping, and there is no
        /// slot for them: `content.text` (an alert shows a title only), any action past the first,
        /// and — from iOS 26.1 — the stop button's own copy.
        public func schedule(
            requestCode: Int32,
            triggerAt: Date,
            content: ReminderNotificationContent,
            ref: ReminderRef
        ) async throws {
            // Nothing is drawn without a provider: a `.custom` secondary button with no intent
            // behind it is a button that does nothing, which is worse than the button being absent.
            let secondaryAction = intents == nil ? nil : content.actions.first
            let secondaryButton = secondaryAction.map { action in
                AlarmButton(
                    text: LocalizedStringResource(stringLiteral: action.label),
                    textColor: .white,
                    systemImageName: "checkmark"
                )
            }
            let secondaryIntent = secondaryAction.flatMap { action in
                intents?.actionIntent(requestCode: requestCode, actionId: action.id)
            }
            let attributes = AlarmAttributes(
                presentation: AlarmPresentation(alert: alert(titled: content.title, secondary: secondaryButton)),
                metadata: ReminderAlarmMetadata(ref: ref),
                tintColor: tintColor
            )
            let configuration = AlarmManager.AlarmConfiguration.alarm(
                schedule: .fixed(triggerAt),
                attributes: attributes,
                stopIntent: intents?.stopIntent(requestCode: requestCode),
                secondaryIntent: secondaryIntent,
                // The system alarm sound, the twin of Android's `RingtoneManager` default
                // (`AlarmSoundPlayer`). v1 ships no asset of its own — see ``ReminderAlarmSound``.
                sound: .default
            )

            _ = try await AlarmManager.shared.schedule(
                id: ReminderAlarmIdentity.alarmId(for: requestCode),
                configuration: configuration
            )
        }

        /// The alert, built through whichever of the two initializers this OS has.
        ///
        /// `title` is a runtime string the handler already localized; wrapping it as a
        /// `LocalizedStringResource` looks it up, misses, and falls back to the string itself,
        /// which is the intended result. AlarmKit takes nothing else.
        ///
        /// From 26.1 the stop button is the system's — it has no parameter, and the `stopButton`
        /// property Apple left behind is documented as no longer used. On 26.0 it is mandatory and
        /// app-supplied, so ``ReminderStrings/alarmDismiss`` fills it; that initializer is
        /// deprecated *at* 26.1, which is exactly the branch it is called from.
        private func alert(titled title: String, secondary: AlarmButton?) -> AlarmPresentation.Alert {
            let title = LocalizedStringResource(stringLiteral: title)
            let behavior: AlarmPresentation.Alert.SecondaryButtonBehavior? = secondary == nil ? nil : .custom

            if #available(iOS 26.1, *) {
                return AlarmPresentation.Alert(
                    title: title,
                    secondaryButton: secondary,
                    secondaryButtonBehavior: behavior
                )
            }
            return AlarmPresentation.Alert(
                title: title,
                stopButton: AlarmButton(
                    text: LocalizedStringResource(stringLiteral: dismissLabel),
                    textColor: .white,
                    systemImageName: "xmark"
                ),
                secondaryButton: secondary,
                secondaryButtonBehavior: behavior
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
