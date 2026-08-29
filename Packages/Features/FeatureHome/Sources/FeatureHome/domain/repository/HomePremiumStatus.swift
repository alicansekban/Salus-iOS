// No Kotlin counterpart file — the same narrowing as `HomeAiSummaryAvailability`, for the other
// half of Android's AI card.
//
// Android's `HomeViewModel` takes `PremiumRepository` (`HomeViewModel.kt:19`) and reads
// `status.isEntitled` — `!= FREE`, so `GRACE_PERIOD` counts as premium
// (`core/premium/.../PremiumStatus.kt:15-17`). Home never calls `refresh()` and never launches a
// purchase, so it depends on the one boolean below rather than on the repository.
//
// The three-state `PremiumStatus` is deliberately **not** ported here: collapsing it to
// "entitled" at the boundary is what keeps `GRACE_PERIOD` from becoming a decision every screen
// re-makes. iOS-M9 brings the real entitlement, and it binds this protocol.
//
// `AsyncStream` rather than `AsyncThrowingStream`: Kotlin's source is a `StateFlow`, which cannot
// fail either.

/// Whether the user is entitled to premium features, for the dashboard's AI card
/// (`PremiumRepository.kt:12`, `PremiumStatus.kt:15-17`).
public protocol HomePremiumStatus: Sendable {
    /// Emits the current entitlement on subscription, then once per change.
    var isPremium: AsyncStream<Bool> { get }
}
