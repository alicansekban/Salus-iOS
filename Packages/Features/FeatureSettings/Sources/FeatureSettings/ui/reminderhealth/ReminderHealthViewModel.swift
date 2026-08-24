// Ported from `feature/settings/src/main/kotlin/com/alicansekban/salus/feature/settings/
// ui/reminderhealth/ReminderHealthViewModel.kt`.
//
// Two shape differences, both forced by the platform rather than chosen:
//
//   * The reads are `async`. Android's three questions are synchronous system calls
//     (`AndroidReminderEnvironment.kt`); `UNUserNotificationCenter.notificationSettings()` is not,
//     so `refresh()` suspends and `isLoading` is a state the screen really passes through.
//   * The fix path prompts. Android's `FixNotifications` sends the user to a settings Intent and
//     the Activity result comes back into the composable (`ReminderHealthScreen.kt:56-63`); iOS has
//     a runtime prompt for both authorizations, so the ViewModel asks first and falls back to
//     Settings only when the answer is no. That fall-through lives here, where it can be asserted,
//     rather than in the view.
//
// `Channel(BUFFERED, DROP_OLDEST)` + `receiveAsFlow()` has no `@Observable` twin: there is no
// subscription-count hook and no flow to collect. The effect is a published property the screen
// consumes, which is the pattern the app layer already uses for a tapped reminder
// (`AppCompositionRoot.ReminderOpenRouter`).

import Foundation
import Observation
import SalusCommon
import SalusReminder

/// Reads what the OS will and will not let the reminder pipeline do, and offers the two prompts
/// that can change the answer (`ReminderHealthViewModel.kt:12-52`).
@MainActor
@Observable
public final class ReminderHealthViewModel {
    public private(set) var state = ReminderHealthUiState()

    /// The effect waiting for the screen, if any — `Channel.trySend` with a queue of one.
    ///
    /// One rather than `Channel.BUFFERED` because both effects open a URL and the second would be
    /// dropped by the system anyway; a queue would only let the screen open Settings twice.
    public private(set) var pendingEffect: ReminderHealthEffect?

    private let environment: any ReminderEnvironment
    private let authorization: any ReminderAuthorizationRequesting
    private let syncState: any ReminderSyncStateStore
    private let clock: any SalusClock
    private let alarmKitSupported: Bool

    /// - Parameters:
    ///   - environment: the read-only view of device state (`ReminderHealthViewModel.kt:13`).
    ///   - authorization: the prompting half. Separate from `environment` because asking is a
    ///     user-visible action; in the app both are the one `SystemReminderEnvironment`.
    ///   - syncState: when the engine last completed a pass. Android reads WorkManager's run
    ///     history instead; iOS has no such ledger.
    ///   - clock: the zone the last-pass line is read in. Never `Date()` in feature code.
    ///   - alarmKitSupported: whether this OS has AlarmKit — decided once, in the composition root,
    ///     by the same `#available` that decides whether an AlarmKit backend is built at all.
    public init(
        environment: any ReminderEnvironment,
        authorization: any ReminderAuthorizationRequesting,
        syncState: any ReminderSyncStateStore,
        clock: any SalusClock,
        alarmKitSupported: Bool
    ) {
        self.environment = environment
        self.authorization = authorization
        self.syncState = syncState
        self.clock = clock
        self.alarmKitSupported = alarmKitSupported

        // `init { refresh() }` (`ReminderHealthViewModel.kt:23-25`). Unstructured because `init`
        // cannot await; the task is short and self-completing, so there is nothing to cancel — the
        // cancellation box `VitalsViewModel` needs is for a stream, and this is not one.
        Task { await refresh() }
    }

    /// `ReminderHealthViewModel.kt:27-38`.
    public func onEvent(_ event: ReminderHealthEvent) {
        switch event {
        case .refresh:
            Task { await refresh() }
        case .fixNotifications:
            Task { await fixNotifications() }
        case .fixBackgroundRefresh:
            // No prompt exists for this one: the switch is in Settings and nowhere else, which is
            // also true of Android's battery-optimization card.
            pendingEffect = .openAppSettings
        case .requestAlarmKit:
            Task { await requestAlarmKit() }
        }
    }

    /// Takes the pending effect and clears it, so one tap opens Settings once.
    @discardableResult
    public func consumeEffect() -> ReminderHealthEffect? {
        defer { pendingEffect = nil }
        return pendingEffect
    }

    /// Re-reads every answer (`ReminderHealthViewModel.kt:42-51`).
    ///
    /// Called on every resume because the user toggles these in Settings, outside our process — the
    /// twin of `LifecycleResumeEffect` is the screen's `scenePhase` observer, and this is what it
    /// sends. `internal` rather than private so a test can await the read it triggers instead of
    /// polling for it.
    func refresh() async {
        let notifications = await environment.notificationsAuthorized()
        let alarmKit = await environment.alarmKitAuthorized()

        state = ReminderHealthUiState(
            isLoading: false,
            notificationsEnabled: notifications,
            alarmKitSupported: alarmKitSupported,
            alarmKitAuthorized: alarmKit,
            backgroundRefreshAvailable: environment.backgroundRefreshAvailable(),
            lastSyncAt: syncState.lastSyncCompletedAt,
            timeZone: clock.timeZone()
        )
    }

    /// Ask, then fall back to Settings — the iOS shape of `ReminderHealthScreen.kt:56-63`, where a
    /// denied permission is followed by the app notification settings screen.
    ///
    /// A prompt that has already been answered cannot be shown again and reports false, so the
    /// fall-through covers both "declined just now" and "declined once, months ago".
    private func fixNotifications() async {
        if await !authorization.requestNotificationAuthorization() {
            pendingEffect = .openNotificationSettings
        }
        await refresh()
    }

    /// The same for AlarmKit. Below iOS 26.1 there is nothing to authorize and the row that sends
    /// this event is not drawn, so the request answers false and the user is sent to Settings only
    /// where Settings has something to show.
    private func requestAlarmKit() async {
        if await !authorization.requestAlarmKitAuthorization() {
            pendingEffect = .openAppSettings
        }
        await refresh()
    }
}
