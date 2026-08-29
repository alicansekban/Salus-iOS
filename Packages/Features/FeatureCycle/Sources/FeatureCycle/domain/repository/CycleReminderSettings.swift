// Ported 1:1 from Android
// `feature/cycle/src/main/kotlin/com/alicansekban/salus/feature/cycle/domain/repository/CycleReminderSettings.kt`.
//
// Two divergences from the Kotlin twin, both forced by the store underneath rather than chosen:
//
// 1. `config` is a non-throwing `AsyncStream`, not `AsyncThrowingStream`. Android's DataStore
//    `Flow` can fail on an IO error; the iOS side reads `UserDefaults` through
//    `SalusSettings`' `DefaultsValueStream`, which cannot. Promising a failure that can never
//    arrive would give every collector a `catch` branch with nothing to put in it.
// 2. The setters are synchronous. Kotlin's are `suspend` because DataStore's `edit` is;
//    `UserDefaults.set` is not, and the whole `SalusPreferencesDataSource` surface
//    (`setCycleReminderEnabled`, `setCycleReminderLeadDays`, `setCycleReminderMinuteOfDay`) is
//    already synchronous. An `async` here would only be a suspension point that never suspends.

/// Domain view of the period-reminder options; the preference store stays behind the data layer
/// (`CycleReminderSettings.kt:6-12`).
public struct CycleReminderConfig: Equatable, Sendable {
    public let enabled: Bool
    /// Days before the predicted start; 0 = the predicted day itself.
    public let leadDays: Int
    /// Local time of day for the reminder, as minuteOfDay.
    public let minuteOfDay: Int

    public init(enabled: Bool, leadDays: Int, minuteOfDay: Int) {
        self.enabled = enabled
        self.leadDays = leadDays
        self.minuteOfDay = minuteOfDay
    }
}

/// `CycleReminderSettings.kt:14-23`.
public protocol CycleReminderSettings: Sendable {
    /// `CycleReminderSettings.kt:16`.
    var config: AsyncStream<CycleReminderConfig> { get }

    /// `CycleReminderSettings.kt:18`.
    func setEnabled(_ enabled: Bool)

    /// `CycleReminderSettings.kt:20`.
    func setLeadDays(_ days: Int)

    /// `CycleReminderSettings.kt:22`.
    func setMinuteOfDay(_ minuteOfDay: Int)
}
