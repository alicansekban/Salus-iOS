// The two `AppIntents` behind an AlarmKit alert's buttons — the iOS twin of the `PendingIntent`s
// Android's `ReminderPendingIntents.action(context, requestCode, actionId)` hands the alarm
// notification (`core/reminder/.../ReminderPendingIntents.kt`), and the reason
// `ReminderActionReceiver` has no iOS file of its own: AlarmKit runs an intent where Android
// broadcasts.
//
// They live in the APP TARGET and cannot live anywhere else. An intent's metadata is extracted at
// app build time from the target that declares it, so an intent shipped inside a package would
// never be registered — and these two have to reach the composition root's graph, which is the app
// target's own.
//
// Both carry the request code and nothing else, because that is all the ledger's lookup needs
// (`ReminderActionDispatcher.perform(requestCode:actionId:)`, Kotlin's
// `HandleReminderActionUseCase`). `Int` rather than `Int32`: `@Parameter` is declared over
// `_IntentValue`, which `Int` conforms to and `Int32` does not.

#if canImport(AppIntents)

    import AppIntents
    import SalusReminder

    /// The alert's stop button on iOS 26.0 — ``ReminderActionIds/dismiss``.
    ///
    /// The noise ends and the occurrence stays unresolved, which is the only safe reading of a
    /// button the OS may draw in its own words: silencing an alarm must never be recorded as having
    /// taken a dose.
    struct ReminderAlarmStopIntent: LiveActivityIntent {
        /// `AppIntent` demands one. Never shown by the alarm surface — the alert draws the button's
        /// own label, not the intent's title — so this is Shortcuts' name for an action that
        /// ``isDiscoverable`` hides from Shortcuts.
        static let title: LocalizedStringResource = "Stop reminder alarm"

        /// The whole point of running in the background: the user answered from the lock screen and
        /// must not be dropped into the app for it. Android's receiver does not launch the activity
        /// either.
        static let openAppWhenRun = false

        /// Kept out of Shortcuts, Spotlight and the Siri suggestions list. These two intents are
        /// plumbing for a button iOS draws; they are not actions a user would ever compose with,
        /// and ``title`` above is deliberately not part of the app's localized copy.
        static let isDiscoverable = false

        @Parameter(title: "Request code")
        var requestCode: Int

        init() {}

        init(requestCode: Int) {
            self.requestCode = requestCode
        }

        func perform() async throws -> some IntentResult {
            await AlarmActionBridge.shared.perform(
                // Truncating, not trapping: this body runs on the lock screen, where a trap is a
                // crash, and the value round-trips from the `Int32` the app scheduled
                // (`@Parameter` has no `Int32` form, so it travels as an `Int`).
                requestCode: Int32(truncatingIfNeeded: requestCode),
                actionId: ReminderActionIds.dismiss
            )
            return .result()
        }
    }

    /// The alert's secondary button: the handler's own first action, e.g. a dose's "Aldım".
    ///
    /// The action id travels with the intent rather than being baked into a type per action,
    /// because the engine's actions are declared by handlers at sync time and the app layer has no
    /// business enumerating them.
    struct ReminderAlarmActionIntent: LiveActivityIntent {
        static let title: LocalizedStringResource = "Answer reminder alarm"

        static let openAppWhenRun = false

        static let isDiscoverable = false

        @Parameter(title: "Request code")
        var requestCode: Int

        @Parameter(title: "Action id")
        var actionId: String

        init() {}

        init(requestCode: Int, actionId: String) {
            self.requestCode = requestCode
            self.actionId = actionId
        }

        func perform() async throws -> some IntentResult {
            await AlarmActionBridge.shared.perform(
                // Truncating, not trapping: this body runs on the lock screen, where a trap is a
                // crash, and the value round-trips from the `Int32` the app scheduled
                // (`@Parameter` has no `Int32` form, so it travels as an `Int`).
                requestCode: Int32(truncatingIfNeeded: requestCode),
                actionId: actionId
            )
            return .result()
        }
    }

#endif
