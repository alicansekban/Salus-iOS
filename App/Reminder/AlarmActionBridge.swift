import SalusReminder

/// The one door between an `AppIntents` intent and the composition root's reminder graph.
///
/// **This is the app target's single sanctioned `static let shared`, and the carve-out is named
/// here rather than argued case by case.** CLAUDE.md's rule is "no global, no `static let shared`,
/// no service locator: a type that needs a dependency takes it in `init`". An `AppIntent` cannot:
/// the SYSTEM instantiates it, through the `init()` the `AppIntent` protocol requires, in a process
/// iOS may have launched for no other reason than to run that one intent. There is no call site to
/// pass the graph through, so the intent needs a rendezvous point it can reach by name — and one
/// rendezvous point held by the app target is a far smaller hole than a service locator, because
/// the only thing that ever passes through it is the dispatcher `AppCompositionRoot` built.
///
/// An `actor` rather than a lock: `bind` and `perform` race by construction. iOS runs the intent
/// and launches the app concurrently, and while `SalusApp.init` binds before any intent body can
/// realistically get this far, the OS guarantees no order between the two. So a `perform` that
/// arrives first **waits** for the bind instead of being dropped — dropping it would silently lose
/// a dose the user answered from the lock screen, which is the one outcome this whole surface
/// exists to prevent.
actor AlarmActionBridge {
    static let shared = AlarmActionBridge()

    /// The graph's alarm-path dispatcher, once `AppCompositionRoot` has one.
    private var dispatcher: ReminderActionDispatcher?

    /// Every `perform` that arrived before the bind. Resumed in one pass by ``bind(_:)``.
    private var waiting: [CheckedContinuation<ReminderActionDispatcher, Never>] = []

    private init() {}

    /// Hands the bridge the dispatcher every intent from here on runs through, and releases
    /// whatever was already waiting for it.
    ///
    /// Called once, from ``AppCompositionRoot/startReminderEngine()`` — i.e. from `SalusApp.init`,
    /// the earliest point in the process that has a graph at all.
    func bind(_ dispatcher: ReminderActionDispatcher) {
        self.dispatcher = dispatcher
        let waiting = waiting
        self.waiting = []
        for continuation in waiting {
            continuation.resume(returning: dispatcher)
        }
    }

    /// Runs one answered alarm through the engine: resolve the request code against the ledger,
    /// let the owning handler act, refill the window.
    func perform(requestCode: Int32, actionId: String) async {
        await boundDispatcher().perform(requestCode: requestCode, actionId: actionId)
    }

    /// The dispatcher, waiting for the bind if it has not happened yet.
    private func boundDispatcher() async -> ReminderActionDispatcher {
        if let dispatcher {
            return dispatcher
        }
        return await withCheckedContinuation { continuation in
            waiting.append(continuation)
        }
    }
}
