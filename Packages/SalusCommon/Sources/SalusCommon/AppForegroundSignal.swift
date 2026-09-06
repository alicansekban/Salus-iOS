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
//
// Two guards sit between the shell's `.active` arm and the fan-out, because "the app came to the
// foreground" is not the same event as "the scene turned active":
//
//   1. **A real background stay must stand behind it.** A cold start turns the scene `.active`
//      while SwiftUI is *also* running `HomeScreen`'s `.task`, which already counts that launch as
//      an open. The two race, in either order, and un-armed the launch would count twice. So the
//      signal is armed only by ``sceneDidEnterBackground()`` and disarmed the moment it fires: the
//      cold start counts once (through `.task`), and every later return counts once (through here).
//   2. **The app-lock gate must be down.** The gate is a `ZStack` overlay over the whole tab tree
//      (`RootView.swift`), so Home never disappears behind it and its ViewModel still believes it
//      is visible. Firing while locked would count a return the user has not been let into yet —
//      and could put the StoreKit sheet on top of the lock screen. A locked arrival is therefore
//      held and released by ``lockGateDidLift()``, which `AppLockManager.didUnlock` drives.

@MainActor
public final class AppForegroundSignal {
    public struct Subscription: Hashable, Sendable {
        fileprivate let id: Int
    }

    private var handlers: [Int: @MainActor () -> Void] = [:]
    private var nextId = 0

    /// Whether a real background stay stands behind the next `.active` (guard 1). Set by
    /// ``sceneDidEnterBackground()``, cleared the moment the fan-out runs.
    private var sawBackground = false

    /// An armed arrival that landed on a locked app and is waiting for the gate (guard 2).
    private var deferredUntilUnlock = false

    public init() {}

    /// Registers `handler` to run on every fan-out until ``unsubscribe(_:)``.
    public func subscribe(_ handler: @escaping @MainActor () -> Void) -> Subscription {
        nextId += 1
        let subscription = Subscription(id: nextId)
        handlers[subscription.id] = handler
        return subscription
    }

    public func unsubscribe(_ subscription: Subscription) {
        handlers[subscription.id] = nil
    }

    /// The shell's `.background` arm: arms the signal, so the next `.active` is a return rather
    /// than the tail of a cold start (guard 1).
    public func sceneDidEnterBackground() {
        sawBackground = true
    }

    /// The shell's `.active` arm. Fans out only for an armed arrival on an unlocked app; a locked
    /// one is held until ``lockGateDidLift()``.
    ///
    /// - Parameter isLocked: `AppLockManager.isLocked` read at this instant. The shell passes it
    ///   rather than the signal holding the manager: the manager is what decides, and one reader
    ///   of it keeps that the only source of truth.
    public func sceneDidBecomeActive(isLocked: Bool) {
        guard sawBackground else { return }
        guard isLocked == false else {
            deferredUntilUnlock = true
            return
        }
        fire()
    }

    /// The app-lock gate came down (`AppLockManager.didUnlock`). Releases the arrival
    /// ``sceneDidBecomeActive(isLocked:)`` held, and does nothing when there is none — an unlock
    /// the app was never locked *away* from is not a foreground return.
    public func lockGateDidLift() {
        guard deferredUntilUnlock else { return }
        fire()
    }

    /// Handlers run in subscription order. Disarms first, so one background stay can only ever
    /// produce one fan-out.
    private func fire() {
        sawBackground = false
        deferredUntilUnlock = false
        for key in handlers.keys.sorted() {
            handlers[key]?()
        }
    }
}
