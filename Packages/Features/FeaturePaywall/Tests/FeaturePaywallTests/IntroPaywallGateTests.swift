// Ported 1:1 from
// feature/paywall/src/test/kotlin/com/alicansekban/salus/feature/paywall/domain/IntroPaywallGateTest.kt
// (4 cases). Case names are the Kotlin backtick names in camelCase.
//
// Divergence from the Kotlin (see IntroPaywallGate.swift's class comment): the Android twin takes
// a separate injectable `markShown` closure, so its class-4 case records `paywallController.request`
// from inside that hook. iOS folds the mark into `SalusPreferencesDataSource.setPaywallIntroShown`,
// which is a concrete `final class` (not a protocol) — it cannot be faked or subclassed, and there
// is no `FakeSalusPreferencesDataSource` anywhere in SalusTesting or the feature modules. These
// tests therefore drive the REAL store over a throwaway `UserDefaults` suite (the same
// `TestUserDefaults`-style isolation SalusSettingsTests uses) plus the real `PaywallController`, and
// assert the flag and the paywall through the store and controller rather than through a `markShown`
// hook. The mark-before-show ordering itself is structurally guaranteed on iOS: both operations are
// synchronous statements on the main actor with no suspension between them, so neither scheduling
// nor a process death can ever reorder them.

import Foundation
import SalusModel
import SalusPremium
import SalusSettings
import Testing

@testable import FeaturePaywall

@Suite("IntroPaywallGate (Android parity)")
@MainActor
struct IntroPaywallGateTests {
    /// A throwaway `UserDefaults` suite, wiped when it goes away — the twin of
    /// `TestUserDefaults` in SalusSettingsTests. The name carries a fresh UUID so tests running in
    /// parallel cannot see each other's writes, and `removePersistentDomain` in `deinit` keeps the
    /// plist off the developer's machine. A class, not a struct: `deinit` only exists on a class.
    final class DisposableDefaults {
        let suiteName: String
        let defaults: UserDefaults

        init() throws {
            let suiteName = "salus-m9-\(UUID().uuidString)"
            self.suiteName = suiteName
            defaults = try #require(
                UserDefaults(suiteName: suiteName),
                "UserDefaults refused the suite name \(suiteName)"
            )
        }

        deinit {
            defaults.removePersistentDomain(forName: suiteName)
        }
    }

    private struct Fixture {
        let gate: IntroPaywallGate
        let source: SalusPreferencesDataSource
        let controller: PaywallController
        /// Retains the defaults so the suite is not wiped from under the store mid-test.
        let suite: DisposableDefaults
    }

    /// Builds a gate over a fresh in-memory store. `preconfigure` (Android's `settings.value = …`)
    /// runs before the gate is constructed, so the store is in its "already seen / already
    /// completed" state for the cases that want one.
    @MainActor
    private func makeFixture(
        billingConfigured: Bool,
        preconfigure: (SalusPreferencesDataSource) -> Void = { _ in }
    ) throws -> Fixture {
        let suite = try DisposableDefaults()
        let flagStore = InMemoryAppLockFlagStore()
        let source = SalusPreferencesDataSource(defaults: suite.defaults, appLockFlagStore: flagStore)
        preconfigure(source)
        let controller = PaywallController()
        let gate = IntroPaywallGate(
            preferences: source,
            paywallController: controller,
            isBillingConfigured: { billingConfigured }
        )
        return Fixture(gate: gate, source: source, controller: controller, suite: suite)
    }

    /// The store's current settings — the twin of reading `settings.value` on Android's
    /// `MutableStateFlow` (`IntroPaywallGateTest.kt`): both data sources emit the stored value as
    /// soon as a consumer arrives.
    @MainActor
    private func currentSettings(_ source: SalusPreferencesDataSource) async -> UserSettings {
        var iterator = source.userSettings.makeAsyncIterator()
        return await iterator.next() ?? UserSettings()
    }

    @Test("waits for onboarding to complete, then shows the intro and marks it")
    func waitsForOnboardingToCompleteThenShowsTheIntroAndMarksIt() async throws {
        let fixture = try makeFixture(billingConfigured: true)
        let source = fixture.source
        let controller = fixture.controller

        // A plain `Task`, not a background scope: run() is expected to return on its own, and a
        // test that fails because the gate never stops waiting is exactly the signal we want.
        let job = Task { await fixture.gate.run() }

        // Onboarding is still on screen; nothing may cover it.
        #expect(controller.request == nil)
        #expect(await !currentSettings(source).paywallIntroShown)

        source.setOnboardingCompleted(true)
        await waitUntil("the paywall opens") { controller.request?.source == .onboarding }

        #expect(await (currentSettings(source)).paywallIntroShown)
        #expect(controller.request?.source == .onboarding)
        // The gate stops collecting once it has fired.
        await job.value
    }

    /// Pins the gate's core invariant that the first test's setup cannot: there, onboarding is
    /// completed before `run()` executes, so the wait resolves on the first element and never
    /// exercises the predicate. Here the gate is started while onboarding is still incomplete and
    /// must NOT fire — the paywall stays closed and the one-time flag stays unset — until
    /// onboarding completes. This is the `Flow.first { }` twin: `first { }` suspends until an
    /// element matching the predicate arrives, it does not return the first element unconditionally.
    @Test("does not fire while onboarding is incomplete, then fires once it completes")
    func doesNotFireWhileOnboardingIsIncompleteThenFiresOnceItCompletes() async throws {
        let fixture = try makeFixture(billingConfigured: true)
        let source = fixture.source
        let controller = fixture.controller

        let job = Task { await fixture.gate.run() }

        // Onboarding is still on screen; the gate must not cover it, and must not burn the flag.
        #expect(controller.request == nil)
        #expect(await !currentSettings(source).paywallIntroShown)

        source.setOnboardingCompleted(true)
        await waitUntil("the paywall opens") { controller.request?.source == .onboarding }

        #expect(await (currentSettings(source)).paywallIntroShown)
        #expect(controller.request?.source == .onboarding)
        await job.value
    }

    @Test("never shows or re-marks the intro once it has been shown")
    func neverShowsOrReMarksTheIntroOnceItHasBeenShown() async throws {
        let fixture = try makeFixture(billingConfigured: true) { source in
            source.setOnboardingCompleted(true)
            source.setPaywallIntroShown(true)
        }

        await fixture.gate.run()

        #expect(fixture.controller.request == nil)
        // Still marked; nothing was re-shown.
        let settings = await currentSettings(fixture.source)
        #expect(settings.paywallIntroShown)
        #expect(settings.onboardingCompleted)
    }

    /// A build with no store key can sell nothing, so the introduction is not an announcement, it
    /// is a dead end — and burning the one-time flag on it would cost the real announcement on the
    /// next build that does have a key.
    @Test("never shows or marks the intro when billing is not configured")
    func neverShowsOrMarksTheIntroWhenBillingIsNotConfigured() async throws {
        let fixture = try makeFixture(billingConfigured: false)
        fixture.source.setOnboardingCompleted(true)

        await fixture.gate.run()

        #expect(fixture.controller.request == nil)
        // The flag is untouched, so a later configured build still gets its one chance.
        #expect(await !currentSettings(fixture.source).paywallIntroShown)
    }

    /// The flag is written before the paywall opens. On Android that ordering is pinned by a
    /// `markShown` hook that records `controller.request` while the paywall is still closed; iOS
    /// folds the mark into the data source and both calls are adjacency-synchronous on the main
    /// actor, so the ordering is structural. This case pins the observable invariant instead: by
    /// the time the run returns, the flag is written and the paywall is open at `.onboarding`.
    @Test("marks the intro shown before opening the paywall")
    func marksTheIntroShownBeforeOpeningThePaywall() async throws {
        let fixture = try makeFixture(billingConfigured: true)
        fixture.source.setOnboardingCompleted(true)

        await fixture.gate.run()

        let settings = await currentSettings(fixture.source)
        #expect(settings.paywallIntroShown)
        #expect(fixture.controller.request?.source == .onboarding)
    }
}
