import Testing

@testable import SalusNavigation

@Suite("Navigator")
@MainActor
struct NavigatorTests {
    /// The Kotlin table this mirrors: `NavigatorImpl` sends onto a `Channel`, so the shell sees
    /// exactly what was asked for, in the order it was asked (`Navigator.kt:42-52`).
    @Test("commands arrive in the order they were issued")
    func emitsInOrder() async {
        let navigator = Navigator()
        var iterator = navigator.commands.makeAsyncIterator()

        navigator.navigate(SampleHomeKey.detail("a"))
        navigator.pop()
        navigator.navigate(SampleVitalsKey.root)

        #expect(await iterator.next() == .navigate(AnyNavKey(SampleHomeKey.detail("a"))))
        #expect(await iterator.next() == .pop)
        #expect(await iterator.next() == .navigate(AnyNavKey(SampleVitalsKey.root)))
    }

    /// `Navigator.kt:40-42`: the channel is buffered "so a ViewModel navigating during init
    /// (before the shell starts collecting) is not dropped on the floor". Everything below is
    /// issued before the first `next()`, so a stream that dropped on no-consumer would fail here.
    @Test("commands issued before anyone consumes the stream are kept")
    func bufferedBeforeFirstConsumer() async {
        let navigator = Navigator()

        for index in 0 ..< 32 {
            navigator.navigate(SampleHomeKey.detail("\(index)"))
        }

        var iterator = navigator.commands.makeAsyncIterator()
        for index in 0 ..< 32 {
            #expect(await iterator.next() == .navigate(AnyNavKey(SampleHomeKey.detail("\(index)"))))
        }
    }

    /// `pop()` needs no key at all — the reason every `NavKey` can stay inside the feature that
    /// owns it (`Navigator.kt:18-24`).
    @Test("pop carries no key")
    func popCarriesNoKey() async {
        let navigator = Navigator()
        var iterator = navigator.commands.makeAsyncIterator()

        navigator.pop()

        #expect(await iterator.next() == NavCommand.pop)
    }

    /// A key that is already erased is not erased twice, so what the shell receives compares equal
    /// to what a feature would have pushed directly.
    @Test("navigating with an already-erased key round-trips")
    func navigateAcceptsAnyNavKey() async {
        let navigator = Navigator()
        var iterator = navigator.commands.makeAsyncIterator()

        navigator.navigate(AnyNavKey(SampleHomeKey.root))

        #expect(await iterator.next() == .navigate(AnyNavKey(SampleHomeKey.root)))
    }
}
