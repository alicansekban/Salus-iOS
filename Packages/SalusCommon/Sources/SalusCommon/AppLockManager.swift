// Ported 1:1 from Android
// `app/src/main/kotlin/com/alicansekban/salus/lock/AppLockManager.kt:19-52`.
//
// It lives in `SalusCommon` rather than in the app target for the reason `PendingDeleteController`
// does: the app target has no test bundle (`project.yml`'s `scheme.testTargets: []`), and this is
// the whole of the lock's logic — a state machine over two booleans and a timestamp, with no UI
// framework anywhere in it. The shell owns the two things that *are* platform: the scenePhase
// callbacks below and the `LAContext` prompt (`App/Lock/LockPrompting.swift`).
//
// Four divergences from the Kotlin twin, all forced by the platform and recorded here so a reader
// sees them without leaving the file:
//
//   1. **`DefaultLifecycleObserver` → two methods the shell calls.** Kotlin registers the manager
//      on `ProcessLifecycleOwner` (`SalusApplication.kt`), which is why the twins take a
//      `LifecycleOwner` the manager never reads. iOS has no process lifecycle owner; `SalusApp`'s
//      `onChange(of: scenePhase)` is the equivalent, and it is the shell's job to call these two.
//      `.inactive` is deliberately *not* one of them: iOS sends it for a control-centre pull or an
//      incoming call, which Android would not call "leaving the app" (the app-switcher blur is a
//      separate concern — ruling 2's `PrivacyOverlay`).
//   2. **`Flow<Boolean>` → `AsyncStream<Bool>`, `combine` → a stored fold.** Kotlin derives
//      `isLocked` as a cold `combine` of the setting flow and `unlockedThisSession`
//      (`AppLockManager.kt:27-29`). `@Observable` has no combine, so the setting is folded into a
//      stored property by the observation task and `isLocked` is recomputed on every change —
//      the same value, published rather than pulled.
//   3. **`isLocked` starts `true`, where `MainActivity` collects with `initialValue = false`**
//      (`MainActivity.kt:84-85`). The initial value is what the gate shows before the setting has
//      been read, and on iOS that window is a real frame: `RootView` renders synchronously while
//      the stream's first emission is still a task hop away. Starting locked means the worst case
//      is a gate that disappears; starting unlocked means the worst case is the app's contents
//      drawn to someone who was supposed to be stopped by the lock. The flash the choice would
//      otherwise cost is already paid for by the onboarding gate's splash-hold (M8 ruling 3), which
//      keeps `RootView` blank until the same `userSettings` stream answers.
//   4. **`nowMs` is a parameter as well as a clock read.** Kotlin's `onStart`/`onStop` read
//      `clock.now()` themselves; the two methods below do the same when `nowMs` is `nil`, which is
//      the production spelling. The parameter exists because the shell already holds a reading when
//      it forwards a scenePhase change, and passing it keeps the pair of timestamps that decide the
//      grace consistent with each other.

import Foundation
import Observation

/// Tracks whether the app-lock gate must cover the UI.
///
/// A cold start begins locked when the setting is on (no unlock this session yet), and returning to
/// the foreground after more than ``lockTimeoutMs`` in the background re-locks. The gate is an
/// overlay above the nav root, so the back stack and pending deep links survive the lock
/// (`AppLockManager.kt:12-17`).
///
/// Application-scoped: it watches the whole process, not one screen. Switching tabs, pushing a
/// destination or rotating the device must not count as "leaving the app", which is why the only
/// two inputs are the scene's own background/active transitions.
@MainActor
@Observable
public final class AppLockManager {
    /// How long the app may stay in the background before the gate comes back, in milliseconds.
    ///
    /// `LOCK_TIMEOUT = 30.seconds` (`AppLockManager.kt:48-51`) — "Fixed by product decision — no UI
    /// option", Android's comment verbatim. It is a constant rather than an injected parameter for
    /// the same reason it is one there: the Kotlin test walks its own clock to `LOCK_TIMEOUT ± 1 s`
    /// instead of shortening the window, and so does `AppLockManagerTests`.
    public static let lockTimeoutMs: Int64 = 30000

    /// Whether the gate must cover the UI — `enabled && !unlocked` (`AppLockManager.kt:27-29`),
    /// recomputed on every change rather than combined on demand (divergence 2).
    ///
    /// Starts `true`: the setting has not been read yet, and an unread setting must not draw the
    /// app's contents (divergence 3).
    public private(set) var isLocked = true

    /// Whether the setting stream has produced its first value.
    ///
    /// Internal on purpose, the `PendingDeleteController.windowTask(id:)` precedent: the app never
    /// needs it, and this package's tests use it to wait for the state Kotlin's `isLocked.first()`
    /// suspends until.
    private(set) var hasReadSetting = false

    /// `MutableStateFlow(false)` (`AppLockManager.kt:24`) — a cold start begins locked when the
    /// setting is on, because nothing has unlocked this session yet.
    private var unlockedThisSession = false

    /// `backgroundedAtMs: Long?` (`AppLockManager.kt:25`). `nil` means "never backgrounded in this
    /// process", which is a cold start and therefore locks.
    private var backgroundedAtMs: Int64?

    /// The latest value of the setting stream, folded in by the observation (divergence 2).
    private var appLockEnabled = false

    private let clock: any SalusClock

    /// The observation. Boxed so `deinit` can cancel it — see ``CancellationBox``.
    private let observation = CancellationBox()

    /// - Parameters:
    ///   - appLockEnabled: the setting, already de-duplicated by the caller — the twin of Koin's
    ///     `userSettings.map { it.appLockEnabled }.distinctUntilChanged()` (`AppModules.kt:45-52`).
    ///   - clock: what `sceneDidBecomeActive`/`sceneDidEnterBackground` read when the caller passes
    ///     no reading of its own (divergence 4).
    public init(appLockEnabled: AsyncStream<Bool>, clock: any SalusClock) {
        self.clock = clock
        observation.replace(with: Task { [weak self] in
            for await enabled in appLockEnabled {
                guard let self, !Task.isCancelled else { return }
                self.appLockEnabled = enabled
                hasReadSetting = true
                publish()
            }
        })
    }

    deinit {
        observation.cancel()
    }

    /// The app returned to the foreground — `onStart(owner)` (`AppLockManager.kt:31-38`).
    ///
    /// Re-locks when the app has never been backgrounded in this process (a cold start) or when it
    /// stayed away for longer than ``lockTimeoutMs``. The comparison is Kotlin's strict `>`, so
    /// exactly the timeout is still the same session.
    ///
    /// - Parameter nowMs: the instant the app returned. `nil` reads the injected clock, which is
    ///   what Kotlin does (divergence 4).
    public func sceneDidBecomeActive(nowMs: Int64? = nil) {
        let now = nowMs ?? clock.nowEpochMilliseconds()
        // `backgroundedAt == null || now - backgroundedAt > LOCK_TIMEOUT` (`AppLockManager.kt:33-35`),
        // with the null branch folded into the optional's own `?? true`.
        let stayedAwayTooLong = backgroundedAtMs.map { now - $0 > Self.lockTimeoutMs } ?? true
        if stayedAwayTooLong {
            unlockedThisSession = false
            publish()
        }
    }

    /// The app left the foreground — `onStop(owner)` (`AppLockManager.kt:40-42`).
    ///
    /// - Parameter nowMs: the instant the app left. `nil` reads the injected clock (divergence 4).
    public func sceneDidEnterBackground(nowMs: Int64? = nil) {
        backgroundedAtMs = nowMs ?? clock.nowEpochMilliseconds()
    }

    /// Authentication succeeded; the gate stays down for the rest of this session
    /// (`AppLockManager.kt:44-46`).
    public func unlock() {
        unlockedThisSession = true
        publish()
    }

    /// `combine(appLockEnabled, unlockedThisSession) { enabled, unlocked -> enabled && !unlocked }`
    /// (`AppLockManager.kt:27-29`), evaluated wherever Kotlin's combine would have re-emitted.
    private func publish() {
        isLocked = appLockEnabled && !unlockedThisSession
    }
}
