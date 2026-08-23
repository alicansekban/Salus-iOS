import SwiftUI
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

    /// The regression this exists for: a single stored `AsyncStream` ends for good the first time
    /// its consumer is cancelled, and SwiftUI cancels a `.task` every time its view leaves the
    /// hierarchy. Kotlin's `Channel.receiveAsFlow()` survives a re-collect (`Navigator.kt:44`), so
    /// this must too — otherwise navigation is silently dead for the rest of the process.
    @Test("a cancelled consumer does not kill the navigator")
    func survivesConsumerCancellation() async {
        let navigator = Navigator()

        let consumer = Task { @MainActor () -> NavCommand? in
            var iterator = navigator.commands.makeAsyncIterator()
            return await iterator.next()
        }
        navigator.navigate(SampleHomeKey.root)
        #expect(await consumer.value == .navigate(AnyNavKey(SampleHomeKey.root)))
        consumer.cancel()

        var iterator = navigator.commands.makeAsyncIterator()
        navigator.navigate(SampleVitalsKey.root)
        #expect(await iterator.next() == .navigate(AnyNavKey(SampleVitalsKey.root)))
    }

    /// The other half of the same property: a command issued in the gap — after the old consumer
    /// ended, before the new one subscribes — goes back into the backlog instead of being handed to
    /// a dead stream.
    @Test("a command issued between two consumers is kept")
    func keepsCommandsIssuedBetweenConsumers() async {
        let navigator = Navigator()

        do {
            var iterator = navigator.commands.makeAsyncIterator()
            navigator.navigate(SampleHomeKey.root)
            #expect(await iterator.next() == .navigate(AnyNavKey(SampleHomeKey.root)))
        }

        navigator.pop()

        var iterator = navigator.commands.makeAsyncIterator()
        #expect(await iterator.next() == .pop)
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

/// The seam between the two halves of this package, which nothing pinned before: `Navigator`
/// erases a feature's key into `AnyNavKey`, the app shell reads the command and calls
/// `TabBackStacks.push`, and what has to come out the far end is the **concrete** key — a
/// `navigationDestination(for: SampleHomeKey.self)` never matches a box.
///
/// `NavigatorTests` stops at the command and `TabBackStacksPushTests` starts at an `AnyNavKey`
/// built by hand; between them sits `RootView.observeNavigationCommands()` (`RootView.swift:153-159`,
/// the twin of `SalusApp.kt:92-99`), which lives in the app target and has no test bundle. This
/// case runs that four-line switch here so the round trip is covered end to end.
@Suite("Navigator → TabBackStacks")
@MainActor
struct NavigatorBackStackTests {
    @Test("navigate lands the concrete key in the selected tab's path")
    func navigateLandsTheConcreteKeyInThePath() async {
        let navigator = Navigator()
        let stacks = TabBackStacks<SampleTab>(initial: .home)
        var iterator = navigator.commands.makeAsyncIterator()

        navigator.navigate(SampleHomeKey.detail("a"))
        navigator.navigate(SampleVitalsKey.root)
        navigator.pop()

        // `RootView.observeNavigationCommands()`, verbatim.
        for _ in 0 ..< 3 {
            switch await iterator.next() {
            case let .navigate(key): stacks.push(key)
            case .pop: stacks.pop()
            case nil: Issue.record("the navigator ended its stream")
            }
        }

        // The pop removed the vitals key; the home key survives with its own type intact, which is
        // the property `NavigationPath` equality is sensitive to.
        #expect(stacks.path(for: .home) == NavigationPath([SampleHomeKey.detail("a")]))
        #expect(stacks.path(for: .vitals).isEmpty)
        #expect(stacks.path(for: .more).isEmpty)
    }
}
