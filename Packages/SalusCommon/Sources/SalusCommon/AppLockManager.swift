// Ported 1:1 from Android
// `app/src/main/kotlin/com/alicansekban/salus/lock/AppLockManager.kt:19-52`.
//
// It lives in `SalusCommon` rather than in the app target for the reason `PendingDeleteController`
// does: the app target has no test bundle (`project.yml`'s `scheme.testTargets: []`), and this is
// the whole of the lock's logic — a state machine over two booleans and a timestamp, with no UI
// framework anywhere in it. The shell owns the two things that *are* platform: the scenePhase
// callbacks below and the `LAContext` prompt (`App/Lock/LockPrompting.swift`).
//
// Five divergences from the Kotlin twin, all forced by the platform and recorded here so a reader
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
//      otherwise cost is paid for twice over: by the onboarding gate's splash-hold (M8 ruling 3),
//      which keeps `RootView` blank until the same `userSettings` stream answers, and by
//      `hasReadSetting` below, which the shell gates the gate on so the cover is a guarantee rather
//      than a matter of which stream answers first.
//   4. **`nowMs` is a parameter as well as a clock read.** Kotlin's `onStart`/`onStop` read
//      `clock.now()` themselves; the two methods below do the same when `nowMs` is `nil`, which is
//      the production spelling. The parameter exists because the shell already holds a reading when
//      it forwards a scenePhase change, and passing it keeps the pair of timestamps that decide the
//      grace consistent with each other.
//   5. **Only a scene that reached the background may re-lock.** Kotlin re-locks when
//      `backgroundedAt == null || now - backgroundedAt > LOCK_TIMEOUT` (`AppLockManager.kt:33-35`),
//      and the null half is unreachable-by-construction there: `ProcessLifecycleOwner.onStart`
//      fires only when the process really returns to the foreground, so a `BiometricPrompt` drawn
//      over the app is not a lifecycle event at all. iOS has no such filter — the Face ID sheet,
//      Control Centre and an incoming call all drive the scene `.active → .inactive → .active`,
//      and the shell forwards that last `.active` here. Ported literally, the null half therefore
//      re-locked the app the instant its own unlock prompt succeeded, which put the gate back up,
//      which fired the prompt again: the Face ID loop. So the null half is dropped (the cold start
//      is already locked by `unlockedThisSession == false`) and the stamp is cleared once judged,
//      so a stay ruled short cannot age into a re-lock at the next round trip.

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
    /// **The shell must not draw the gate until this is `true`.** ``isLocked`` starts `true` on
    /// purpose (divergence 3), which means that before the first emission it says "locked" for a
    /// setting nobody has read yet — and a gate drawn in that window fires ``AppLockScreen``'s
    /// automatic prompt at someone who never enabled the lock. Ruling 3's splash-hold (the blank
    /// `RootView` frame until `userSettings` answers) reads the same stream and usually covers it,
    /// but "usually" is task-ordering luck; this is the signal that makes it a guarantee.
    ///
    /// Public for that reason, and only that reason: it is not part of the state machine, and no
    /// caller should branch on it for anything but "may I draw the gate yet". This package's tests
    /// also use it to wait for the state Kotlin's `isLocked.first()` suspends until.
    public private(set) var hasReadSetting = false

    /// `MutableStateFlow(false)` (`AppLockManager.kt:24`) — a cold start begins locked when the
    /// setting is on, because nothing has unlocked this session yet.
    private var unlockedThisSession = false

    /// `backgroundedAtMs: Long?` (`AppLockManager.kt:25`). `nil` means "no unjudged background stay
    /// stands": either the app has never left in this process, or the stay it recorded has already
    /// been ruled on by ``sceneDidBecomeActive(nowMs:)``. Either way there is nothing to re-lock for
    /// (divergence 5) — a cold start is already locked by `unlockedThisSession == false`.
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
    /// Re-locks when the app stayed away for longer than ``lockTimeoutMs``. The comparison is
    /// Kotlin's strict `>`, so exactly the timeout is still the same session.
    ///
    /// A scene that never reached the background does nothing here — divergence 5.
    ///
    /// - Parameter nowMs: the instant the app returned. `nil` reads the injected clock, which is
    ///   what Kotlin does (divergence 4).
    public func sceneDidBecomeActive(nowMs: Int64? = nil) {
        // Kotlin's `backgroundedAt == null ||` branch (`AppLockManager.kt:33`) is deliberately not
        // ported (divergence 5). There it can only ever be the cold start, because
        // `ProcessLifecycleOwner` reports nothing else; here it would also be every
        // `.active → .inactive → .active` round trip.
        //
        // The cold start needs no branch of its own: `unlockedThisSession` starts `false`, so the
        // gate is already up before this is first called.
        guard let leftAtMs = backgroundedAtMs else { return }
        // Spent once, so a stay already judged short cannot age into a re-lock at the next round
        // trip. Kotlin never clears it because `onStart` cannot fire without an `onStop` first.
        backgroundedAtMs = nil
        let now = nowMs ?? clock.nowEpochMilliseconds()
        if now - leftAtMs > Self.lockTimeoutMs {
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
