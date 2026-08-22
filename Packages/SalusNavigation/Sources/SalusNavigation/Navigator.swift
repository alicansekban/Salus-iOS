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
    /// Consumed by the app shell. Single-consumer by construction, exactly as Kotlin's
    /// `Channel.receiveAsFlow()` is (`Navigator.kt:28-29, 44`): a second consumer would not see a
    /// copy of the commands, it would steal them.
    public let commands: AsyncStream<NavCommand>

    private let continuation: AsyncStream<NavCommand>.Continuation

    public init() {
        // Unbounded, so a ViewModel navigating during init — before the shell starts consuming —
        // is not dropped on the floor (`Navigator.kt:40-42`, `Channel.BUFFERED`). The traffic is
        // one command per user tap, so there is nothing here for a bound to protect.
        let (stream, continuation) = AsyncStream<NavCommand>.makeStream(bufferingPolicy: .unbounded)
        commands = stream
        self.continuation = continuation
    }

    deinit {
        // Ends the shell's `for await` when the root goes away, rather than leaving it suspended
        // on a stream nothing will ever write to again.
        continuation.finish()
    }

    /// Pushes `key`. The caller must be able to see the key, i.e. own it (`Navigator.kt:31-33`).
    public func navigate(_ key: some Hashable & Sendable) {
        continuation.yield(.navigate(AnyNavKey(key)))
    }

    /// Pops the current entry (`Navigator.kt:34-35`).
    public func pop() {
        continuation.yield(.pop)
    }
}
