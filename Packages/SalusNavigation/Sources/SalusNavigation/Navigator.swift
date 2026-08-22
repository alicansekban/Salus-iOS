// Ported 1:1 from
// `core/navigation/src/main/kotlin/com/alicansekban/salus/core/navigation/Navigator.kt:26-53`.
//
// Kotlin splits the type in two — a `Navigator` interface and a `NavigatorImpl` — because Koin
// hands out the interface and keeps the implementation off the graph (`NavigationModule.kt`).
// There is no container here, and one concrete `@MainActor` class is already substitutable: a test
// that wants to observe navigation reads `commands`, which is the whole surface. Splitting it would
// port Koin's shape rather than the type's behaviour.
//
// NOT in scope: `SalusTransitions.kt`. Screen transitions belong to the pushed entry on Android and
// to the `NavigationStack` presentation on iOS; that port lands with the first pushed screen, not
// with the navigator.

/// Lets a ViewModel act on navigation directly, instead of modelling "close this screen" as a
/// one-member Effect that the Route has to collect and translate (`Navigator.kt:14-25`).
///
/// The Navigator deliberately does **not** hold the back stack: it is owned by the composition
/// root and would outlive the view that owns `TabBackStacks`. It publishes commands, and the app
/// shell — still the only thing that mutates the stack — applies them.
///
/// It also knows nothing about which keys exist. `pop()` needs no key at all, which is what lets
/// every navigation key stay inside the feature that owns it. Cross-feature navigation stays wired
/// in the shell.
@MainActor
public final class Navigator {
    /// Commands not yet handed to a consumer.
    ///
    /// Kotlin's `Channel` holds this buffer itself and keeps it across collectors; an `AsyncStream`
    /// buffer dies with its iterator, so the backlog lives here instead.
    private var pending: [NavCommand] = []

    /// The live consumer, if one is attached. At most one, always.
    private var continuation: AsyncStream<NavCommand>.Continuation?

    public init() {}

    /// Consumed by the app shell. Single-consumer at a time, exactly as Kotlin's
    /// `Channel.receiveAsFlow()` is (`Navigator.kt:28-29, 44`): a second consumer would not see a
    /// copy of the commands, it would steal them — so subscribing again ends the previous stream
    /// rather than fanning out.
    ///
    /// A *new* stream per access, and that is the point. A single stored `AsyncStream` ends for
    /// good the first time its consumer is cancelled — SwiftUI cancels a `.task` whenever its view
    /// leaves the hierarchy — after which every `yield` returns `.terminated` and navigation is
    /// silently dead for the rest of the process. `receiveAsFlow()` survives a re-collect; so does
    /// this. Same shape as `SalusPreferencesDataSource.userSettings`.
    ///
    /// Whatever was issued before anyone subscribed is delivered first, in order, so a ViewModel
    /// that navigates during init is not dropped on the floor (`Navigator.kt:40-42`,
    /// `Channel.BUFFERED`).
    public var commands: AsyncStream<NavCommand> {
        // Unbounded: the traffic is one command per user tap, so there is nothing for a bound to
        // protect, and a dropped navigation is a bug the user sees.
        let (stream, continuation) = AsyncStream<NavCommand>.makeStream(bufferingPolicy: .unbounded)
        for command in pending {
            continuation.yield(command)
        }
        pending.removeAll()
        self.continuation?.finish()
        self.continuation = continuation
        return stream
    }

    /// Pushes `key`. The caller must be able to see the key, i.e. own it (`Navigator.kt:31-33`).
    public func navigate(_ key: some Hashable & Sendable) {
        send(.navigate(AnyNavKey(key)))
    }

    /// Pops the current entry (`Navigator.kt:34-35`).
    public func pop() {
        send(.pop)
    }

    /// Hands `command` to the live consumer, or holds it until one arrives.
    ///
    /// A consumer whose task was cancelled reports `.terminated` on the next yield; the command it
    /// refused goes back into the backlog for whoever subscribes next, rather than vanishing.
    private func send(_ command: NavCommand) {
        guard let continuation else {
            pending.append(command)
            return
        }
        if case .terminated = continuation.yield(command) {
            self.continuation = nil
            pending.append(command)
        }
    }
}
