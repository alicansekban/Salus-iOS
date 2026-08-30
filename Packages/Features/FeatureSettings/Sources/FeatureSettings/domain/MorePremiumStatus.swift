// No direct Kotlin counterpart file — the iOS-M8 stand-in for Android's `PremiumRepository.status`,
// narrowed to the two states the More tab needs (ruling 5).
//
// Android's `MoreViewModel` reads `PremiumRepository.status` (`PremiumStatus.kt:15-17`), a
// three-state value: `FREE`, `GRACE_PERIOD`, `ENTITLED`. iOS-M9 brings the store and the real
// entitlement; until then there is nothing truthful to answer with except "free", so the More tab
// carries the seam — a `MorePremiumStatus` protocol and a `MorePremiumStatusValue` two-state enum —
// and `FreeOnlyMorePremiumStatus` binds it to `.free` once, never finishing.
//
// **Two-state, not three** (ruling 5): the `GRACE_PERIOD` middle state is a billing-platform
// concept that has no meaning before the store exists. Collapsing to `free`/`entitled` at the
// boundary is what keeps the More tab from re-making a three-way decision the store will own. The
// `HomePremiumStatus` twin (`FeatureHome/domain/repository/HomePremiumStatus.swift`) makes the same
// call for its own one-boolean view; the More tab needs the value itself, so this protocol surfaces
// it as an enum rather than a `Bool`.
//
// The enum is `Equatable` so `MoreViewModel` can `==` it in its state-equator, and `Sendable` so it
// can travel through an `AsyncStream` under Swift 6 strict concurrency.

/// The premium entitlement the More tab shows, narrowed to the two states that exist before the
/// store arrives (ruling 5).
public enum MorePremiumStatusValue: Equatable, Sendable {
    /// The user has no premium entitlement — the default, and what `FreeOnlyMorePremiumStatus`
    /// emits.
    case free
    /// The user is entitled to premium features. Only a real store implementation (iOS-M9) emits
    /// this; the `FakeMorePremiumStatus` in tests flips to it on demand.
    case entitled
}

/// The premium entitlement, as the More tab's domain sees it.
///
/// `AsyncStream` rather than `AsyncThrowingStream`: the Kotlin source is a `StateFlow`, which
/// cannot fail.
public protocol MorePremiumStatus: Sendable {
    /// Emits the current entitlement on subscription, then once per change.
    var status: AsyncStream<MorePremiumStatusValue> { get }
}
