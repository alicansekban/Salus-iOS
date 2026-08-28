// Ported from
// `feature/settings/src/test/kotlin/com/alicansekban/salus/feature/settings/ui/reminderhealth/
// ReminderHealthViewModelTest.kt`.
//
// The Android table has five cases; four of them port straight across, one changes shape and two
// iOS-only ones are added:
//
//   `initial state reflects the environment`            → the same, over the iOS three questions.
//   `refresh picks up changes made in system settings`  → the same. On iOS the trigger is
//                                                         `scenePhase == .active` rather than
//                                                         `LifecycleResumeEffect`, but what it
//                                                         sends is this same `.refresh`.
//   `all healthy only when every check passes`          → the same.
//   `a revoked full-screen permission is not healthy`   → `a revoked AlarmKit authorization …`:
//                                                         `canUseFullScreenAlarms` is
//                                                         `alarmKitAuthorized` here
//                                                         (`SystemReminderEnvironment.swift:81-85`).
//   `fix events emit the matching effects`              → split in two, because the iOS fix path is
//                                                         not Android's. Android sends the user to a
//                                                         settings Intent; iOS PROMPTS first and
//                                                         falls back to Settings only when the
//                                                         prompt cannot help. So there is one case
//                                                         for "the prompt granted it, no effect" and
//                                                         one for "the prompt said no, open
//                                                         Settings".
//
//   iOS-only: `AlarmKit is not counted where there is no AlarmKit` — below iOS 26.0 the row is not
//   drawn, so counting its permanent `false` would paint a permanently unhealthy screen with
//   nothing to fix on it. Android has no twin: `canUseFullScreenAlarms()` answers true below the
//   API level that can revoke it.
//   iOS-only: the last-pass stamp, which Android reads out of WorkManager's run history.
//
// Turbine's `state.test { awaitItem() }` becomes reading `viewModel.state` after `waitUntil`, and
// its `effects.test { awaitItem() }` becomes reading `pendingEffect` — the same substitution the
// M2 ViewModel tests already made for `@Observable`.

import Foundation
import SalusTesting
import Testing

@testable import FeatureSettings

@Suite("ReminderHealthViewModel")
@MainActor
struct ReminderHealthViewModelTests {
    /// A fixed instant and zone, so the last-pass line reads the same wherever the test runs.
    private static let now = Date(timeIntervalSince1970: 1_755_000_000)
    private static let zone = FixedSalusClock.defaultZone

    private let clock = FixedSalusClock(
        now: ReminderHealthViewModelTests.now,
        timeZone: ReminderHealthViewModelTests.zone
    )

    private func viewModel(
        environment: FakeReminderEnvironment,
        syncState: FakeReminderSyncStateStore = FakeReminderSyncStateStore(),
        alarmKitSupported: Bool = true
    ) -> ReminderHealthViewModel {
        ReminderHealthViewModel(
            environment: environment,
            authorization: environment,
            syncState: syncState,
            clock: clock,
            alarmKitSupported: alarmKitSupported
        )
    }

    /// `ReminderHealthViewModelTest.kt:26-37`.
    @Test("initial state reflects the environment")
    func initialStateReflectsTheEnvironment() async {
        let environment = FakeReminderEnvironment(
            notifications: false,
            alarmKit: true,
            backgroundRefresh: false
        )
        let model = viewModel(environment: environment)

        await waitUntil("the first read to land") { !model.state.isLoading }

        #expect(model.state.notificationsEnabled == false)
        #expect(model.state.alarmKitAuthorized == true)
        #expect(model.state.backgroundRefreshAvailable == false)
        #expect(model.state.allHealthy == false)
    }

    /// `ReminderHealthViewModelTest.kt:39-49`.
    @Test("refresh picks up changes made in system settings")
    func refreshPicksUpChangesMadeInSystemSettings() async {
        let environment = FakeReminderEnvironment(notifications: false)
        let model = viewModel(environment: environment)
        await waitUntil("the first read to land") { !model.state.isLoading }

        environment.set(notifications: true)
        await model.refresh()

        #expect(model.state.notificationsEnabled)
        #expect(model.state.allHealthy)
    }

    /// `ReminderHealthViewModelTest.kt:70-74`.
    @Test("all healthy only when every check passes")
    func allHealthyOnlyWhenEveryCheckPasses() async {
        let model = viewModel(environment: FakeReminderEnvironment())

        await waitUntil("the first read to land") { !model.state.isLoading }

        #expect(model.state.allHealthy)
    }

    /// `ReminderHealthViewModelTest.kt:76-82` — `canUseFullScreenAlarms` is `alarmKitAuthorized`.
    @Test("a revoked AlarmKit authorization is not healthy")
    func aRevokedAlarmKitAuthorizationIsNotHealthy() async {
        let model = viewModel(environment: FakeReminderEnvironment(alarmKit: false))

        await waitUntil("the first read to land") { !model.state.isLoading }

        #expect(model.state.alarmKitAuthorized == false)
        #expect(model.state.allHealthy == false)
    }

    /// No Android twin: below iOS 26.0 there is no AlarmKit at all, `alarmKitAuthorized()` answers
    /// a permanent false, and the row is not drawn. Counting it would paint an unhealthy screen
    /// with nothing on it to fix.
    @Test("AlarmKit is not counted where there is no AlarmKit")
    func alarmKitIsNotCountedWhereThereIsNoAlarmKit() async {
        let model = viewModel(
            environment: FakeReminderEnvironment(alarmKit: false),
            alarmKitSupported: false
        )

        await waitUntil("the first read to land") { !model.state.isLoading }

        #expect(model.state.alarmKitSupported == false)
        #expect(model.state.alarmKitAuthorized == false)
        #expect(model.state.allHealthy)
    }

    /// The healthy half of `fix events emit the matching effects`
    /// (`ReminderHealthViewModelTest.kt:51-68`): the prompt is the iOS fix, and a granted prompt
    /// needs no trip to Settings.
    @Test("a granted prompt fixes the row without opening Settings")
    func aGrantedPromptFixesTheRowWithoutOpeningSettings() async {
        let environment = FakeReminderEnvironment(
            notifications: false,
            alarmKit: false,
            notificationPromptGrants: true,
            alarmKitPromptGrants: true
        )
        let model = viewModel(environment: environment)
        await waitUntil("the first read to land") { !model.state.isLoading }

        model.onEvent(.fixNotifications)
        await waitUntil("notifications to come back authorized") { model.state.notificationsEnabled }
        #expect(environment.notificationPromptCount == 1)
        #expect(model.pendingEffect == nil)

        model.onEvent(.requestAlarmKit)
        await waitUntil("AlarmKit to come back authorized") { model.state.alarmKitAuthorized }
        #expect(environment.alarmKitPromptCount == 1)
        #expect(model.pendingEffect == nil)
        #expect(model.state.allHealthy)
    }

    /// The declined half. Android's `RequestNotificationAccess` falls through to the app
    /// notification settings screen when the permission comes back denied
    /// (`ReminderHealthScreen.kt:56-63`); this is that fall-through, moved into the ViewModel where
    /// it can be asserted.
    @Test("a declined prompt asks the screen to open Settings")
    func aDeclinedPromptAsksTheScreenToOpenSettings() async {
        let environment = FakeReminderEnvironment(
            notifications: false,
            alarmKit: false,
            notificationPromptGrants: false,
            alarmKitPromptGrants: false
        )
        let model = viewModel(environment: environment)
        await waitUntil("the first read to land") { !model.state.isLoading }

        model.onEvent(.fixNotifications)
        await waitUntil("the notification-settings effect") { model.pendingEffect != nil }
        #expect(model.consumeEffect() == .openNotificationSettings)
        #expect(model.pendingEffect == nil)

        model.onEvent(.requestAlarmKit)
        await waitUntil("the app-settings effect") { model.pendingEffect != nil }
        #expect(model.consumeEffect() == .openAppSettings)
    }

    /// Background App Refresh has no prompt — the switch is in Settings and nowhere else — so this
    /// event opens Settings straight away. It is the twin of Android's
    /// `OpenBatteryOptimizationSettings`, which also opens a settings screen without asking first.
    @Test("the background-refresh fix opens Settings, with no prompt to show first")
    func theBackgroundRefreshFixOpensSettings() async {
        let environment = FakeReminderEnvironment(backgroundRefresh: false)
        let model = viewModel(environment: environment)
        await waitUntil("the first read to land") { !model.state.isLoading }

        model.onEvent(.fixBackgroundRefresh)

        #expect(model.consumeEffect() == .openAppSettings)
        #expect(environment.notificationPromptCount == 0)
        #expect(environment.alarmKitPromptCount == 0)
    }

    /// No Android twin: WorkManager keeps its own run history, iOS keeps this stamp.
    @Test("the last-pass stamp is carried into the state")
    func theLastPassStampIsCarriedIntoTheState() async {
        let stamp = Self.now.addingTimeInterval(-3600)
        let model = viewModel(
            environment: FakeReminderEnvironment(),
            syncState: FakeReminderSyncStateStore(lastSyncCompletedAt: stamp)
        )

        await waitUntil("the first read to land") { !model.state.isLoading }

        #expect(model.state.lastSyncAt == stamp)
        #expect(model.state.timeZone == Self.zone)
    }

    /// An install where the engine has never completed a pass reports nil rather than 1970 — the
    /// distinction `UserDefaultsReminderSyncStateStore` goes out of its way to preserve.
    @Test("an install that has never synced carries no stamp")
    func anInstallThatHasNeverSyncedCarriesNoStamp() async {
        let model = viewModel(environment: FakeReminderEnvironment())

        await waitUntil("the first read to land") { !model.state.isLoading }

        #expect(model.state.lastSyncAt == nil)
    }

    /// A refresh re-reads the stamp too: a foreground pass writes it while the screen is open.
    @Test("refresh re-reads the last-pass stamp")
    func refreshReReadsTheLastPassStamp() async {
        let syncState = FakeReminderSyncStateStore()
        let model = viewModel(environment: FakeReminderEnvironment(), syncState: syncState)
        await waitUntil("the first read to land") { !model.state.isLoading }

        syncState.recordSyncCompleted(at: Self.now)
        await model.refresh()

        #expect(model.state.lastSyncAt == Self.now)
    }
}
