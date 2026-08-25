// An iOS-only wiring seam with no Android twin: Koin resolves lazily, so `AppointmentsModule.kt`
// can ask for a `ReminderScheduler` that is itself still being built. Hand-wiring has no such
// deferral, and the composition root's one genuine cycle needs somewhere to break.

import Foundation

/// A ``ReminderScheduler`` whose real target is supplied after construction.
///
/// The cycle it breaks: `ReminderHandlerRegistry` is an immutable value built inside the reminder
/// sub-graph together with the scheduler, the appointment handler needs the appointments
/// repository, and that repository needs a `ReminderScheduler` — so the module has to exist before
/// the scheduler does. The composition root builds this relay first, injects it as the module's
/// scheduler, builds the reminder graph with the module's handler in the registry, and then calls
/// ``bind(_:)`` with the finished scheduler.
///
/// **A call made before binding is dropped, not buffered.** Buffering would be the more obvious
/// choice and is the wrong one: the only window in which a call can arrive unbound is the few
/// statements of `AppCompositionRoot.init`, and nothing in it writes an appointment. Should
/// something ever do so, the foreground reconcile on the first `scenePhase == .active`
/// (`AppCompositionRoot.reminderDidBecomeActive`) refills the whole window from the database
/// anyway — a queued request would only duplicate a pass that is already guaranteed. A buffer, by
/// contrast, would be state that has to be correct forever for a case that has never happened.
public final class ReminderSchedulerRelay: ReminderScheduler, @unchecked Sendable {
    /// `NSLock` rather than `Mutex`: `Mutex` is iOS 18, this package ships to iOS 17, and the
    /// three other guarded snapshots in `platform/` are already spelled this way.
    private let lock = NSLock()
    private var target: (any ReminderScheduler)?

    public init() {}

    /// Points the relay at the real scheduler. Idempotent in the sense that matters — the last
    /// target wins, and there is no accumulated state a rebind could strand.
    public func bind(_ target: any ReminderScheduler) {
        lock.withLock { self.target = target }
    }

    /// Forwards to the bound scheduler, or does nothing when there is none yet.
    ///
    /// The forward happens outside the lock: `requestSync()` is documented as safe to call often
    /// and the real implementation coalesces on a lock of its own, so holding this one across the
    /// call would nest two locks for no reason.
    public func requestSync() {
        let target = lock.withLock { self.target }
        target?.requestSync()
    }
}
