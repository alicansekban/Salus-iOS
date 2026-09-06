import Testing

@testable import SalusCommon

@Suite("AppForegroundSignal")
@MainActor
struct AppForegroundSignalTests {
    @Test("every subscriber hears every signal, in subscription order")
    func fanOut() {
        let signal = AppForegroundSignal()
        var log: [String] = []
        _ = signal.subscribe { log.append("a") }
        _ = signal.subscribe { log.append("b") }

        signal.sceneDidEnterBackground()
        signal.sceneDidBecomeActive(isLocked: false)
        signal.sceneDidEnterBackground()
        signal.sceneDidBecomeActive(isLocked: false)

        #expect(log == ["a", "b", "a", "b"])
    }

    @Test("an unsubscribed handler stops hearing")
    func unsubscribe() {
        let signal = AppForegroundSignal()
        var count = 0
        let subscription = signal.subscribe { count += 1 }

        signal.sceneDidEnterBackground()
        signal.sceneDidBecomeActive(isLocked: false)
        signal.unsubscribe(subscription)
        signal.sceneDidEnterBackground()
        signal.sceneDidBecomeActive(isLocked: false)

        #expect(count == 1)
    }

    @Test("a signal with no subscribers is a no-op")
    func noSubscribers() {
        let signal = AppForegroundSignal()
        signal.sceneDidEnterBackground()
        signal.sceneDidBecomeActive(isLocked: false)
    }

    // MARK: - Guard 1: only a real background arms the signal

    @Test("the cold start's own `.active` fans out to nobody")
    func coldStartDoesNotFire() {
        let signal = AppForegroundSignal()
        var count = 0
        _ = signal.subscribe { count += 1 }

        signal.sceneDidBecomeActive(isLocked: false)

        #expect(count == 0)
    }

    @Test("one background stay produces exactly one fan-out")
    func oneBackgroundOneSignal() {
        let signal = AppForegroundSignal()
        var count = 0
        _ = signal.subscribe { count += 1 }

        signal.sceneDidEnterBackground()
        signal.sceneDidBecomeActive(isLocked: false)
        // The `.active → .inactive → .active` round trip a control-centre pull causes: no
        // background in between, so nothing to report.
        signal.sceneDidBecomeActive(isLocked: false)

        #expect(count == 1)
    }

    // MARK: - Guard 2: the app-lock gate holds the arrival

    @Test("a return onto the lock screen is held until the gate lifts, then fires once")
    func lockedReturnIsDeferred() {
        let signal = AppForegroundSignal()
        var count = 0
        _ = signal.subscribe { count += 1 }

        signal.sceneDidEnterBackground()
        signal.sceneDidBecomeActive(isLocked: true)
        #expect(count == 0)

        signal.lockGateDidLift()

        #expect(count == 1)
    }

    @Test("the gate lifting without a held arrival fans out to nobody")
    func unlockWithoutDeferredArrivalDoesNothing() {
        let signal = AppForegroundSignal()
        var count = 0
        _ = signal.subscribe { count += 1 }

        // The cold start's unlock: the app was locked, but it never returned from anywhere.
        signal.lockGateDidLift()

        #expect(count == 0)
    }

    @Test("a held arrival is spent by the unlock, not re-fired by the next one")
    func deferredArrivalIsSpentOnce() {
        let signal = AppForegroundSignal()
        var count = 0
        _ = signal.subscribe { count += 1 }

        signal.sceneDidEnterBackground()
        signal.sceneDidBecomeActive(isLocked: true)
        signal.lockGateDidLift()
        signal.lockGateDidLift()

        #expect(count == 1)
    }
}
