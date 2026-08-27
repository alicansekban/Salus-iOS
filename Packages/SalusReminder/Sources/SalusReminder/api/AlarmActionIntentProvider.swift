// The seam between the alarm surface and the `AppIntents` types that answer it — the iOS twin of
// the `PendingIntent`s Android's `ReminderPendingIntents.action(context, requestCode, actionId)`
// hands to the alarm notification's buttons.
//
// AlarmKit does not call back into a delegate the way `UNUserNotificationCenter` does. A button on
// an alarm alert runs an `AppIntents` `LiveActivityIntent`, which the system executes in the app's
// process — with the app closed, exactly like Android's `ReminderActionReceiver`. An intent is a
// concrete type the *app target* declares (its metadata is extracted at app build time and it has
// to reach the composition root's graph), so this package declares only what it needs of one: a
// factory that mints the intent for a request code and, for the secondary button, an action id.
//
// The concrete provider arrives with the app's own AppIntents in iOS-M5 Task 13. Until it does,
// ``SystemAlarmKitScheduler`` takes none and the alarm rings with the system stop button alone.
//
// The whole file is behind `#if canImport(AppIntents)` and `@available(macOS, unavailable)`:
// `LiveActivityIntent` is declared unavailable on macOS, and `swift test` builds this package for
// the host.

#if canImport(AppIntents)

    import AppIntents

    /// Mints the `AppIntents` an alarm's buttons run.
    ///
    /// Both verbs answer the same question in different words — "what should run when the user
    /// presses this button" — and both are handed the request code rather than the occurrence
    /// identity, because that is all the ledger's own lookup needs
    /// (``ReminderActionDispatcher/perform(requestCode:actionId:)``, Kotlin's
    /// `HandleReminderActionUseCase`).
    @available(iOS 17.0, *)
    @available(macOS, unavailable)
    @available(watchOS, unavailable)
    @available(tvOS, unavailable)
    public protocol AlarmActionIntentProvider: Sendable {
        /// The intent behind the alert's mandatory stop button, which the engine reads as
        /// ``ReminderActionIds/dismiss``: the noise ends and the occurrence stays unresolved.
        func stopIntent(requestCode: Int32) -> any LiveActivityIntent

        /// The intent behind the alert's optional secondary button — the handler's own first
        /// action, e.g. a dose's "Aldım".
        func actionIntent(requestCode: Int32, actionId: String) -> any LiveActivityIntent
    }

#endif
