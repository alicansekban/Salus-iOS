// The six Kotlin cases from
// `salus-android/app/src/test/kotlin/com/alicansekban/salus/lock/AppLockManagerTest.kt:42-93`,
// ported one for one and by name.
//
// Three substitutions, and nothing else changes:
//
//   * `LifecycleOwner` has no argument here. Kotlin's `onStart(owner)` / `onStop(owner)` take the
//     owner because `DefaultLifecycleObserver` demands it, and the manager never reads it — the
//     Kotlin test's `owner` even throws from `lifecycle` to say so
//     (`AppLockManagerTest.kt:33-36`). The iOS twins are `sceneDidBecomeActive` /
//     `sceneDidEnterBackground`, which the app shell calls from `onChange(of: scenePhase)`.
//   * `MutableStateFlow(true)` becomes `MutableBoolStream`, an `AsyncStream` with a stored
//     continuation that yields its current value on creation and once per `send(_:)` — the
//     `CurrentValueStream` shape `MoreViewModel` already uses, cut down to one consumer.
//   * `manager.isLocked.first()` becomes reading `manager.isLocked` after `waitUntil`. Kotlin
//     awaits the combine's next emission; `@Observable` publishes into a stored property, so the
//     test yields the main actor until the observation task has folded the value in.
//
// `MutableClock` is Kotlin's, verbatim in shape: the same 1_000_000 ms start and the same
// `advance(by:)`, spelled in milliseconds because that is the unit the manager compares in.

import Foundation
import Testing

@testable import SalusCommon

@Suite("AppLockManager")
@MainActor
struct AppLockManagerTests {
    /// `AppLockManagerTest.kt:21-31` — the advanceable clock the timeout cases walk forward.
    private final class MutableClock: SalusClock, @unchecked Sendable {
        private let lock = NSLock()
        private var current = Date(timeIntervalSince1970: 1000)

        func advance(byMilliseconds milliseconds: Int64) {
            lock.withLock { current += Double(milliseconds) / 1000 }
        }

        func now() -> Date {
            lock.withLock { current }
        }

        func timeZone() -> TimeZone {
            .gmt
        }
    }

    /// `MutableStateFlow<Boolean>`'s twin (`AppLockManagerTest.kt:39`): emits its current value at
    /// once, then one value per `send(_:)`, and never finishes.
    private struct MutableBoolStream {
        let stream: AsyncStream<Bool>
        private let continuation: AsyncStream<Bool>.Continuation

        init(_ initial: Bool) {
            (stream, continuation) = AsyncStream.makeStream(of: Bool.self)
            continuation.yield(initial)
        }

        func send(_ value: Bool) {
            continuation.yield(value)
        }
    }

    /// `AppLockManagerTest.kt:38-40` — the three fields every case shares, rebuilt per case so no
    /// state leaks between them.
    ///
    /// The wait is what Kotlin gets for free: `isLocked.first()` suspends until the combine has
    /// both values, so every Kotlin case reads a state the setting has already reached. Here the
    /// observation is a task, so the fixture does not hand back a manager until it has read the
    /// setting once — without it the first assertion could be reading nothing but the initial
    /// value.
    private func makeManager(enabled: Bool = true) async -> (
        manager: AppLockManager,
        clock: MutableClock,
        enabled: MutableBoolStream
    ) {
        let clock = MutableClock()
        let setting = MutableBoolStream(enabled)
        let manager = AppLockManager(appLockEnabled: setting.stream, clock: clock)
        await waitUntil("the app-lock setting to be read") { manager.hasReadSetting }
        return (manager, clock, setting)
    }

    /// `AppLockManagerTest.kt:42-46`.
    @Test("cold start is locked when the setting is on")
    func coldStartIsLockedWhenTheSettingIsOn() async {
        let fixture = await makeManager()

        fixture.manager.sceneDidBecomeActive()

        #expect(fixture.manager.isLocked)
    }

    /// `AppLockManagerTest.kt:48-53`.
    @Test("never locks while the setting is off")
    func neverLocksWhileTheSettingIsOff() async {
        let fixture = await makeManager(enabled: false)

        fixture.manager.sceneDidBecomeActive()

        #expect(fixture.manager.isLocked == false)
    }

    /// `AppLockManagerTest.kt:55-60`.
    @Test("unlock clears the gate")
    func unlockClearsTheGate() async {
        let fixture = await makeManager()

        fixture.manager.sceneDidBecomeActive()
        fixture.manager.unlock()

        #expect(fixture.manager.isLocked == false)
    }

    /// `AppLockManagerTest.kt:62-72`.
    @Test("short background stay keeps the session unlocked")
    func shortBackgroundStayKeepsTheSessionUnlocked() async {
        let fixture = await makeManager()

        fixture.manager.sceneDidBecomeActive()
        fixture.manager.unlock()

        fixture.manager.sceneDidEnterBackground()
        fixture.clock.advance(byMilliseconds: AppLockManager.lockTimeoutMs - 1000)
        fixture.manager.sceneDidBecomeActive()

        #expect(fixture.manager.isLocked == false)
    }

    /// `AppLockManagerTest.kt:74-84`.
    @Test("exceeding the timeout in the background re-locks")
    func exceedingTheTimeoutInTheBackgroundReLocks() async {
        let fixture = await makeManager()

        fixture.manager.sceneDidBecomeActive()
        fixture.manager.unlock()

        fixture.manager.sceneDidEnterBackground()
        fixture.clock.advance(byMilliseconds: AppLockManager.lockTimeoutMs + 1000)
        fixture.manager.sceneDidBecomeActive()

        #expect(fixture.manager.isLocked)
    }

    /// `AppLockManagerTest.kt:86-93`.
    @Test("disabling the setting while locked unlocks immediately")
    func disablingTheSettingWhileLockedUnlocksImmediately() async {
        let fixture = await makeManager()

        fixture.manager.sceneDidBecomeActive()
        #expect(fixture.manager.isLocked)

        fixture.enabled.send(false)
        await waitUntil("the disabled setting to reach the gate") { fixture.manager.isLocked == false }

        #expect(fixture.manager.isLocked == false)
    }

    // MARK: - The boundary itself, which Kotlin's two cases straddle but never name

    /// No Kotlin twin. Cases 4 and 5 sit a second either side of the timeout; this one lands on it
    /// exactly, because `>` and `>=` both pass those two and only disagree here. The comparison is
    /// Kotlin's `>` (`AppLockManager.kt:34`), so exactly 30 s in the background is still the same
    /// session.
    @Test("exactly the timeout in the background is still the same session")
    func exactlyTheTimeoutInTheBackgroundIsStillTheSameSession() async {
        let fixture = await makeManager()

        fixture.manager.sceneDidBecomeActive()
        fixture.manager.unlock()

        fixture.manager.sceneDidEnterBackground()
        fixture.clock.advance(byMilliseconds: AppLockManager.lockTimeoutMs)
        fixture.manager.sceneDidBecomeActive()

        #expect(fixture.manager.isLocked == false)
    }

    /// No Kotlin twin either: Android's `onStart` reads `clock.now()` itself
    /// (`AppLockManager.kt:34`), so a caller-supplied reading is an iOS-only seam and needs its own
    /// case. The shell passes the reading it already holds; passing none reads the injected clock.
    @Test("a caller-supplied reading is used instead of the clock")
    func aCallerSuppliedReadingIsUsedInsteadOfTheClock() async {
        let fixture = await makeManager()
        let backgroundedAt = fixture.clock.now().epochMilliseconds

        fixture.manager.sceneDidBecomeActive()
        fixture.manager.unlock()

        // The clock never moves; the readings do.
        fixture.manager.sceneDidEnterBackground(nowMs: backgroundedAt)
        fixture.manager.sceneDidBecomeActive(nowMs: backgroundedAt + AppLockManager.lockTimeoutMs + 1)

        #expect(fixture.manager.isLocked)
    }
}
