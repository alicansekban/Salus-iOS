// The shell's "the app came to the foreground" fan-out, for ViewModels the composition root does
// not hold.
//
// Android has no twin and needs none: a Compose screen that wants to know it was resumed reads its
// own `LifecycleResumeEffect`, and the process lifecycle re-resumes the visible screen on every
// return from the background. SwiftUI re-runs `.task` / `.onAppear` on appearance only — a return
// from the background is not an appearance — and the one `scenePhase` site that forwards to the
// graph is `SalusApp.swift`'s (`CLAUDE.md`), which reaches the composition root and nothing below
// it. `HomeViewModel` is built lazily by its Route, so the root cannot call it by name; it can
// only call this, which the ViewModel subscribed to when it was built.
//
// A tiny observer list rather than an `AsyncStream`: a stream has one consumer, and a second Home
// ViewModel (a preview, a test graph) would silently starve the first.

@MainActor
public final class AppForegroundSignal {
    public struct Subscription: Hashable, Sendable {
        fileprivate let id: Int
    }

    private var handlers: [Int: @MainActor () -> Void] = [:]
    private var nextId = 0

    public init() {}

    /// Registers `handler` to run on every ``signal()`` until ``unsubscribe(_:)``.
    public func subscribe(_ handler: @escaping @MainActor () -> Void) -> Subscription {
        nextId += 1
        let subscription = Subscription(id: nextId)
        handlers[subscription.id] = handler
        return subscription
    }

    public func unsubscribe(_ subscription: Subscription) {
        handlers[subscription.id] = nil
    }

    /// Called by the shell's `.active` arm. Handlers run in subscription order.
    public func signal() {
        for key in handlers.keys.sorted() {
            handlers[key]?()
        }
    }
}
