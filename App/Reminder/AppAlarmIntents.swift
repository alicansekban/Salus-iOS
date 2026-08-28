#if canImport(AppIntents)

    import AppIntents
    import SalusReminder

    /// The app target's answer to `SalusReminder`'s ``AlarmActionIntentProvider`` seam: it mints the
    /// two intents declared next door, which is the one thing the package cannot do for itself.
    ///
    /// Stateless, so the composition root builds one at the same place it builds
    /// ``SystemAlarmKitScheduler`` and hands it straight in. Without a provider the alarm still
    /// rings and still stops — it simply carries no answer, which was iOS-M3's behaviour.
    struct AppAlarmIntents: AlarmActionIntentProvider {
        func stopIntent(requestCode: Int32) -> any LiveActivityIntent {
            ReminderAlarmStopIntent(requestCode: Int(requestCode))
        }

        func actionIntent(requestCode: Int32, actionId: String) -> any LiveActivityIntent {
            ReminderAlarmActionIntent(requestCode: Int(requestCode), actionId: actionId)
        }
    }

#endif
