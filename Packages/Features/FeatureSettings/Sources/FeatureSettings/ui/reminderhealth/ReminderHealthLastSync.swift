// No Kotlin twin. Android's Reminder Health has no last-run line at all: WorkManager keeps a run
// history, so "did the app get a turn?" is answerable from the platform. iOS has no such ledger —
// a `BGAppRefreshTask` the system chose not to run leaves no trace — so the engine writes its own
// stamp (`ReminderSyncStateStore`) and this turns it into the line the screen draws.

import Foundation

/// The last-pass line.
enum ReminderHealthLastSync {
    /// `d MMM yyyy HH:mm` — day first, 24-hour, no seconds.
    ///
    /// A fixed pattern, never `setLocalizedDateFormatFromTemplate`: a template reorders the
    /// components per region, which is exactly the drift this port avoids elsewhere
    /// (`LocalDateTime.formatted(pattern:locale:)` carries the same note).
    static let pattern = "d MMM yyyy HH:mm"

    /// The line for a stamp, or the "never ran here" sentence when there is none.
    ///
    /// **What the stamp means, and it is narrower than it looks:** it says a reconciliation pass
    /// *ran*, not that the window was verified. `BackgroundRefreshScheduler` records it after every
    /// pass, one that failed part-way through included, so a fresh timestamp is not a promise that
    /// the next seven days are scheduled. The line still earns its place, because the failure it
    /// does catch is the one that actually misleads: a screen showing three healthy rows while
    /// nothing has run for a week (spec §"risk table").
    static func line(for lastSyncAt: Date?, in zone: TimeZone, locale: Locale = .current) -> String {
        guard let lastSyncAt else { return SettingsStrings.reminderHealthNeverSynced }
        return SettingsStrings.reminderHealthLastSync(timestamp(lastSyncAt, in: zone, locale: locale))
    }

    /// One instant read as wall-clock text in `zone`.
    ///
    /// The zone is passed rather than taken from the device, so the reading is the clock's and a
    /// test is deterministic. No `Calendar` is constructed: `DateFormatter` renders an instant in
    /// the zone it is given, which leaves `CLAUDE.md`'s "never a second `Calendar` in the tree"
    /// rule untouched.
    static func timestamp(_ instant: Date, in zone: TimeZone, locale: Locale = .current) -> String {
        // A fresh formatter per call, for the reason `LocalDateTime` gives: `DateFormatter`
        // is neither `Sendable` nor cheap to share, and this one is drawn once per screen.
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeZone = zone
        formatter.dateFormat = pattern
        return formatter.string(from: instant)
    }
}
