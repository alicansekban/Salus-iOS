// The Home-shaped port of `core/premium/.../PremiumRepository.kt:12` plus the `isEntitled`
// read in `HomeViewModel.kt:40`:
//
//     premiumRepository.status.map { it.isEntitled }
//
// Android's `HomeViewModel` takes the whole `PremiumRepository` and reads one member off it
// (`HomeViewModel.kt:21`, `:40`); iOS narrows the dependency to ``HomePremiumStatus``, one
// boolean, so the three-state `PremiumStatus` collapses to "entitled" at this boundary rather
// than becoming a decision every screen re-makes (see `domain/repository/HomePremiumStatus.swift`).
//
// Rebuilt as an `AsyncStream` rather than mapped in place: `AsyncStream.map` answers an
// `AsyncMapSequence`, and the protocol promises the concrete type. `.bufferingNewest(1)` is the
// conflation the source already applies, restated because rebuilding the stream is what mapping
// it costs — `SalusCommon.mapped`'s note, for the non-throwing case.
//
// **This one does not deduplicate**, and the difference is the Kotlin's: `HomeViewModel.kt:40`
// maps `isEntitled` with no `distinctUntilChanged`, so a `GRACE_PERIOD` → `PREMIUM` transition
// (or any other status change that keeps the boolean true) is forwarded as a fresh emission.
// `AiUsageSummaryAvailability` deduplicates only because its Kotlin source chains
// `distinctUntilChanged`; this source does not.

import SalusPremium

/// ``HomePremiumStatus`` over the real entitlement (`PremiumRepository.kt:12`).
///
/// Not `@MainActor`: ``HomePremiumStatus`` is `Sendable` with a nonisolated `isPremium`, and
/// ``PremiumRepository`` is `Sendable` with a nonisolated `status` too, so the mapping needs no
/// actor — the repository's stream is itself thread-safe (`PremiumRepositoryImpl.status` is
/// `nonisolated` for the same reason).
final class PremiumRepositoryHomePremiumStatus: HomePremiumStatus {
    private let premiumRepository: any PremiumRepository

    init(premiumRepository: any PremiumRepository) {
        self.premiumRepository = premiumRepository
    }

    var isPremium: AsyncStream<Bool> {
        // Read before the stream is built: the repository's `status` re-seeds from the current
        // value on every subscription, so nothing written between here and the first iteration
        // is missed.
        let status = premiumRepository.status
        return AsyncStream(bufferingPolicy: .bufferingNewest(1)) { continuation in
            let task = Task {
                for await value in status {
                    continuation.yield(value.isEntitled)
                }
                continuation.finish()
            }
            // A consumer that stops reading must stop the underlying subscription too.
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
