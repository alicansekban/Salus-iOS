// The iOS-M8 stand-in for Android's `PremiumRepository.status`, for the More tab — **recorded
// divergence (d)**, the same shape `FreeOnlyPremiumStatus.swift` reasons out for the Home tab.
//
// Android's `MoreViewModel` reads a real entitlement because `:core:premium` and its billing
// gateway already exist there. On iOS the premium milestone is iOS-M9: no store SDK is on the tree
// yet, `purchases-ios` arrives with that milestone and not before (`CLAUDE.md`, the closed
// allowlist), so there is nothing truthful to answer with except "free".
//
// Pinning it to `.free` rather than leaving the More state field out entirely is ruling 5: the
// state field and the protocol behind it are carried from day one, so iOS-M9 binds a real
// implementation to ``MorePremiumStatus`` and neither the ViewModel nor the screen changes shape.
// The More tab of M8 draws the "upgrade to Premium" row, so the value is visible — but what it
// protects is the seam.
//
// **It emits `.free` once and never finishes**, and both halves are deliberate — see
// `FreeOnlyPremiumStatus.swift:14-24` for the full reasoning, which applies identically here: once,
// because a value that cannot change has nothing to re-emit; never finishes, because the Kotlin
// source is a `StateFlow`, which never completes either, and a placeholder that completed would
// change what "the More tab's stream is still open" means.

/// ``MorePremiumStatus`` until iOS-M9 brings the store.
final class FreeOnlyMorePremiumStatus: MorePremiumStatus {
    var status: AsyncStream<MorePremiumStatusValue> {
        AsyncStream(bufferingPolicy: .bufferingNewest(1)) { continuation in
            continuation.yield(.free)
        }
    }
}
