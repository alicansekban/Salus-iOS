// Ported from `feature/settings/src/main/kotlin/com/alicansekban/salus/feature/settings/
// ui/reminderhealth/ReminderHealthUiState.kt`.
//
// The three UDF types keep their Kotlin names and their Kotlin job; what changes is the list of
// questions, because two of Android's have no iOS reading and one iOS question has no Android one.
// `SettingsStrings.swift`'s header carries the card-by-card table; the state below is its shape.

import Foundation

/// What the screen draws (`ReminderHealthUiState.kt:3-15`).
///
/// Every property has a default so a `#Preview` can build one from `.init()`, and `isLoading`
/// starts true: the three reads are `async` here where Android's were synchronous system calls, so
/// there is a first frame before any answer exists.
public struct ReminderHealthUiState: Equatable, Sendable {
    public var isLoading: Bool
    public var notificationsEnabled: Bool

    /// Whether this OS has AlarmKit at all — iOS 26.0 and up, where `SystemAlarmKitScheduler`
    /// exists (`AppCompositionRoot.makeAlarmKitBackend`).
    ///
    /// Not in the Kotlin, and not a fourth question either: it is the iOS spelling of the
    /// `Build.VERSION.SDK_INT >= UPSIDE_DOWN_CAKE` guard that decides whether Android draws its
    /// full-screen card (`ReminderHealthScreen.kt:180-193`). It lives in the state rather than in
    /// an `#available` inside the view because ``allHealthy`` needs the same fact: a row that is
    /// not drawn must not be counted, or the screen paints a permanently unhealthy verdict with
    /// nothing on it to fix. Two `#available` checks would be two places for that to drift.
    public var alarmKitSupported: Bool

    /// `fullScreenAlarmsEnabled` (`ReminderHealthUiState.kt:8`) — `canUseFullScreenAlarms` is
    /// `alarmKitAuthorized` on iOS (`SystemReminderEnvironment.swift:81-85`).
    public var alarmKitAuthorized: Bool

    /// `ignoringBatteryOptimizations` (`ReminderHealthUiState.kt:7`) — both ask "will the OS let us
    /// run when the app is not open?" (`SystemReminderEnvironment.swift:87-98`).
    public var backgroundRefreshAvailable: Bool

    /// When the engine last completed a reconciliation pass, or nil if none ever has on this
    /// install.
    ///
    /// **It means "a pass ran", not "the window was verified".** `BackgroundRefreshScheduler`
    /// stamps it after every pass, including one that failed internally, so a fresh stamp is not a
    /// promise that every occurrence in the next seven days is scheduled — only that the app got a
    /// turn. It is here because the opposite is what actually misleads: three green rows while
    /// nothing has run for a week (spec §"risk table", and
    /// `ReminderSyncStateStore.swift`'s file header).
    public var lastSyncAt: Date?

    /// The zone ``lastSyncAt`` is read in — the clock's, sampled with it.
    ///
    /// Not in the Kotlin, which formats in the composable's default locale. It is carried in the
    /// state so the screen stays "state + onEvent" with no injected clock of its own, and so the
    /// line is deterministic in a test (`CLAUDE.md`: never `Date()` — or a device zone — in feature
    /// code).
    public var timeZone: TimeZone

    public init(
        isLoading: Bool = true,
        notificationsEnabled: Bool = false,
        alarmKitSupported: Bool = false,
        alarmKitAuthorized: Bool = false,
        backgroundRefreshAvailable: Bool = false,
        lastSyncAt: Date? = nil,
        timeZone: TimeZone = .current
    ) {
        self.isLoading = isLoading
        self.notificationsEnabled = notificationsEnabled
        self.alarmKitSupported = alarmKitSupported
        self.alarmKitAuthorized = alarmKitAuthorized
        self.backgroundRefreshAvailable = backgroundRefreshAvailable
        self.lastSyncAt = lastSyncAt
        self.timeZone = timeZone
    }

    /// `ReminderHealthUiState.kt:10-14`, over the rows this platform draws.
    ///
    /// AlarmKit counts only where it exists: below iOS 26.0 `alarmKitAuthorized()` answers a
    /// permanent false and the row is not drawn, so counting it would make every device on iOS 17
    /// through 25 unhealthy for a reason its user cannot act on. Android's twin is the same
    /// bargain read from the other side — `canUseFullScreenAlarms()` answers *true* below API 34,
    /// where the permission is granted at install time.
    public var allHealthy: Bool {
        notificationsEnabled
            && backgroundRefreshAvailable
            && (alarmKitAuthorized || !alarmKitSupported)
    }
}

/// User intents (`ReminderHealthUiState.kt:17-23`).
///
/// `fixExactAlarms` is dropped — iOS has no exact-alarm permission — and `fixFullScreenAlarms`
/// becomes ``requestAlarmKit``, which names what it does here: Android opens a settings screen,
/// iOS shows a prompt.
public enum ReminderHealthEvent: Equatable, Sendable {
    case refresh
    case fixNotifications
    case fixBackgroundRefresh
    case requestAlarmKit
}

/// One-shot UI work the screen performs (`ReminderHealthUiState.kt:25-30`).
///
/// Both arms open a URL, which is the whole of iOS's "send the user somewhere they can fix it":
/// there are no `Intent` extras to build, so the four Kotlin effects collapse into the two
/// destinations iOS actually has. Navigation is deliberately not modelled here
/// (`docs/ios-feature-template.md`, UDF state types) — this screen pushes nothing.
public enum ReminderHealthEffect: Equatable, Sendable {
    /// `UIApplication.openNotificationSettingsURLString` — the app's notification page, the twin of
    /// `Settings.ACTION_APP_NOTIFICATION_SETTINGS` (`ReminderHealthScreen.kt:117-119`).
    case openNotificationSettings

    /// `UIApplication.openSettingsURLString` — the app's own Settings page, which is where both
    /// the Background App Refresh switch and a declined AlarmKit authorization are changed.
    case openAppSettings
}
