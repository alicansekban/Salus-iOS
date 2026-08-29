// Ported 1:1 from `feature/cycle/src/main/kotlin/com/alicansekban/salus/feature/cycle/data/
// CycleReminderSettingsImpl.kt`.
//
// The two divergences this file carries are the ones ``CycleReminderSettings`` already records and
// does not repeat: `config` is a non-throwing `AsyncStream` because `UserDefaults` cannot fail the
// way DataStore can (divergence (b) is the second half — the setters are synchronous because every
// setter on `SalusPreferencesDataSource` is).
//
// The preference store stays behind this type: nothing in `domain/` or `ui/` imports
// `SalusSettings`, so the three Android-verbatim keys (`cycle_reminder_enabled`,
// `cycle_reminder_lead_days`, `cycle_reminder_minute_of_day`) are named in exactly one place on
// this side of the port — `SettingsKeys`.

import SalusSettings

/// The only implementation of ``CycleReminderSettings`` (`CycleReminderSettingsImpl.kt:9-32`).
///
/// A `final class` rather than a struct, matching the Kotlin: it is one long-lived collaborator the
/// composition root holds, not a value anything copies. Its single stored property is an immutable
/// `Sendable` reference, so the protocol's `Sendable` conformance is checked rather than promised.
final class CycleReminderSettingsImpl: CycleReminderSettings {
    private let dataSource: SalusPreferencesDataSource

    init(dataSource: SalusPreferencesDataSource) {
        self.dataSource = dataSource
    }

    /// `CycleReminderSettingsImpl.kt:13-19` — the whole `UserSettings` narrowed to the three
    /// fields this feature owns, so a change to an unrelated setting cannot wake the reminder
    /// scheduler.
    ///
    /// Rebuilt as an `AsyncStream` rather than mapped in place: `AsyncStream.map` answers an
    /// `AsyncMapSequence`, and the protocol promises the concrete type. `.bufferingNewest(1)` is
    /// the conflation `DefaultsValueStream` already applies to the source, restated because
    /// rebuilding the stream is what mapping it costs — `SalusCommon.mapped`'s note, for the
    /// non-throwing case.
    var config: AsyncStream<CycleReminderConfig> {
        let settings = dataSource.userSettings
        return AsyncStream(bufferingPolicy: .bufferingNewest(1)) { continuation in
            let task = Task {
                for await value in settings {
                    continuation.yield(
                        CycleReminderConfig(
                            enabled: value.cycleReminderEnabled,
                            leadDays: value.cycleReminderLeadDays,
                            minuteOfDay: value.cycleReminderMinuteOfDay
                        )
                    )
                }
                continuation.finish()
            }
            // A consumer that stops reading must stop the underlying subscription too.
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    /// `CycleReminderSettingsImpl.kt:21-23`.
    func setEnabled(_ enabled: Bool) {
        dataSource.setCycleReminderEnabled(enabled)
    }

    /// `CycleReminderSettingsImpl.kt:25-27`.
    func setLeadDays(_ days: Int) {
        dataSource.setCycleReminderLeadDays(days)
    }

    /// `CycleReminderSettingsImpl.kt:29-31`.
    func setMinuteOfDay(_ minuteOfDay: Int) {
        dataSource.setCycleReminderMinuteOfDay(minuteOfDay)
    }
}
