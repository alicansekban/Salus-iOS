// The iOS-M7 stand-in for Android's `PremiumRepository.status` — **recorded divergence (d)**.
//
// Android's Home reads a real entitlement (`HomeViewModel.kt:19`, `:31`) because `:core:premium`
// and its billing gateway already exist there. On iOS the premium milestone is iOS-M9: no store
// SDK is on the tree yet, `purchases-ios` arrives with that milestone and not before (`CLAUDE.md`,
// the closed allowlist), so there is nothing truthful to answer with except "not entitled".
//
// Pinning it to `false` rather than leaving `HomeUiState.isPremium` out entirely is the plan's
// ruling 1: the state field and the two protocols behind it are carried from day one, so iOS-M9
// binds a real implementation to ``HomePremiumStatus`` and neither the ViewModel nor the screen
// changes shape. The Home screen of M7 draws no AI card at all, so the value is not visible yet —
// what it protects is the seam.
//
// **It emits `false` once and never finishes**, and both halves are deliberate:
//
//  - *Once*, because a value that cannot change has nothing to re-emit. There is no store to
//    observe and no setter to publish.
//  - *Never finishes*, because the Kotlin source is a `StateFlow`, which never completes either.
//    A stream that ended after its single value would be a second difference from the type this
//    replaces in iOS-M9 — and `latestOfBoth`'s combined stream finishes only when *all* its sources
//    have finished, so a placeholder that completes would quietly change what "the dashboard's
//    stream is still open" means. Cancellation still ends the iteration: `AsyncStream` terminates
//    its iterator when the consuming task is cancelled, so a collector that goes away is not left
//    waiting on a value that will never come.

/// ``HomePremiumStatus`` until iOS-M9 brings the store (`PremiumRepository.kt:12`).
struct FreeOnlyPremiumStatus: HomePremiumStatus {
    var isPremium: AsyncStream<Bool> {
        AsyncStream(bufferingPolicy: .bufferingNewest(1)) { continuation in
            continuation.yield(false)
        }
    }
}
