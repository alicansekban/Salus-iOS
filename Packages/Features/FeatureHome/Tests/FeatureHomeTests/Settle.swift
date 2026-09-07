// The other half of `WaitUntil.swift`, and this target's single copy of it.
//
// `waitUntil(_:)` proves something *arrived*; `settle()` is what a case needs to prove something
// did **not**. There is no state to wait for in that direction, only a point after which "not yet"
// means "never", so this hands the cooperative pool enough turns for everything already runnable
// to finish and then returns. Turbine spells the same step `expectNoEvents()`; Kotlin's ViewModel
// tests get it from `runTest`'s virtual scheduler, which Swift Testing has no equivalent of.
//
// Like `waitUntil`, it waits on the pool and never on wall-clock time: `Task.yield()` hands the
// executor to whatever is enqueued and comes straight back, so a healthy run costs the two or
// three hops it actually needs and the bound is only there to keep a broken expectation bounded.
//
// **One file, not one per suite.** Three suites here grew a private `settle()` of their own
// (`AiUsageSummaryAvailabilityTests`, `HomeReadinessTests`), with different turn counts and the
// same body; they all call this one now. It is not folded into `WaitUntil.swift` because that file
// is deliberately byte-for-byte identical to `FeatureCycleTests/WaitUntil.swift` — a claim its own
// header makes — and appending to it would quietly break the copy.

/// Hands the cooperative pool enough turns for everything already runnable to finish.
///
/// - Parameter turns: how many yields to spend. Far above the deepest chain any case here needs
///   (an unstructured `Task`, then the collector it feeds), and free once they are done.
func settle(turns: Int = 500) async {
    for _ in 0 ..< turns {
        await Task.yield()
    }
}
