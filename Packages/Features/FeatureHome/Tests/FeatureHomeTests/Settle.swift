// The other half of `SalusTesting`'s `waitUntil`, and this target's single copy of it.
//
// `waitUntil(_:)` proves something *arrived*; `settle()` is what a case needs to prove something
// did **not**. There is no state to wait for in that direction, only a point after which "not yet"
// means "never", so this hands the cooperative pool enough turns for everything already runnable
// to finish and then returns. Turbine spells the same step `expectNoEvents()`; Kotlin's ViewModel
// tests get it from `runTest`'s virtual scheduler, which Swift Testing has no equivalent of.
//
// Unlike `waitUntil`, it spends no wall-clock time: `Task.yield()` hands the executor to whatever
// is enqueued and comes straight back. So it is only ever the LAST step of a negative check, after
// a positive signal (a `waitUntil`, a completion stream) has proved the work it guards has started
// or finished; never the only thing standing between a write and its assertion.
//
// **One file, not one per suite.** Three suites here grew a private `settle()` of their own
// (`AiUsageSummaryAvailabilityTests`, `HomeReadinessTests`), with different turn counts and the
// same body; they all call this one now.

/// Hands the cooperative pool enough turns for everything already runnable to finish.
///
/// - Parameter turns: how many yields to spend. Far above the deepest chain any case here needs
///   (an unstructured `Task`, then the collector it feeds), and free once they are done.
func settle(turns: Int = 500) async {
    for _ in 0 ..< turns {
        await Task.yield()
    }
}
