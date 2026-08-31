// Ported 1:1 from
// feature/paywall/src/main/kotlin/com/alicansekban/salus/feature/paywall/domain/IntroPaywallGate.kt.
//
// One structural divergence from the Kotlin, forced by the iOS twins of its inputs. Android takes
// the settings `Flow` and the `markShown` write as two constructor parameters, keeping the gate a
// "plain suspending object with nothing to stub". iOS has no such twin to pass: the equivalent
// surface is `SalusSettings.SalusPreferencesDataSource` (whose `userSettings` `AsyncStream` plus
// the synchronous `setPaywallIntroShown(_:)`) and `SalusPremium.PaywallController`. Because the
// write is synchronous, the gate never suspends between reading `paywallIntroShown` and setting
// it — the mark-then-show ordering is adjacency-synchronous on the main actor and so structurally
// airtight, which is the invariant the Android test pins with its `markShown` hook.

import SalusModel
import SalusPremium
import SalusSettings

/// Opens the premium introduction exactly once, the first time the app is usable.
///
/// It waits for onboarding rather than firing at launch: the onboarding flow is a full-screen gate
/// drawn above the shell, and a paywall over it would cover a form the user has not finished.
/// Existing users — whose onboarding is long done — pass the wait immediately and so meet the
/// introduction once after updating, which is deliberate: it is how premium is announced to them.
///
/// The gate takes the settings stream and the write through the preferences data source instead of
/// as separate constructor parameters, because on iOS both live on that one object.
///
/// - Parameters:
///   - preferences: the settings store — `userSettings` for the wait, `setPaywallIntroShown` for
///     the one-time mark.
///   - paywallController: the single gate every feature opens the paywall with (`PaywallController`).
///   - isBillingConfigured: whether the store SDK has a key. A build without one can sell nothing,
///     so announcing premium there would open a sheet that only ever says "plans could not be
///     loaded" — and would burn the one-time flag doing it. Read at `run` time because the SDK is
///     configured before Koin, so the answer is already final by then.
@MainActor
public final class IntroPaywallGate {
    private let preferences: SalusPreferencesDataSource
    private let paywallController: PaywallController
    private let isBillingConfigured: () -> Bool

    public init(
        preferences: SalusPreferencesDataSource,
        paywallController: PaywallController,
        isBillingConfigured: @escaping () -> Bool
    ) {
        self.preferences = preferences
        self.paywallController = paywallController
        self.isBillingConfigured = isBillingConfigured
    }

    /// Suspends until the introduction is either shown or established as already seen.
    public func run() async {
        // Checked before the wait: nothing is shown and, crucially, nothing is marked — the next
        // launch of a build that does have a key still gets to announce premium once.
        guard isBillingConfigured() else { return }

        // `userSettings.first { it.onboardingCompleted }` — the `Flow.first { }` twin
        // (`IntroPaywallGate.kt:39`).
        var iterator = preferences.userSettings.makeAsyncIterator()
        let settings = await iterator.next() ?? UserSettings()
        guard !settings.paywallIntroShown else { return }

        // Marked before shown: if the process dies in between, the user misses one announcement —
        // the opposite order would show it on every launch until it stuck. The mark and the show
        // are both synchronous statements adjacent on the main actor, so nothing can slip between
        // them (`IntroPaywallGate.kt:44-45`).
        preferences.setPaywallIntroShown(true)
        paywallController.show(.onboarding)
    }
}
