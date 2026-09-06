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

        signal.signal()
        signal.signal()

        #expect(log == ["a", "b", "a", "b"])
    }

    @Test("an unsubscribed handler stops hearing")
    func unsubscribe() {
        let signal = AppForegroundSignal()
        var count = 0
        let subscription = signal.subscribe { count += 1 }

        signal.signal()
        signal.unsubscribe(subscription)
        signal.signal()

        #expect(count == 1)
    }

    @Test("a signal with no subscribers is a no-op")
    func noSubscribers() {
        AppForegroundSignal().signal()
    }
}
