// Ported 1:1 from
// `feature/settings/src/test/kotlin/com/alicansekban/salus/feature/settings/ui/about/AboutViewModelTest.kt`.
//
// The five cases port by name — the moved-and-renamed Support tests
// (`SupportViewModelTest.kt` on the about-redesign plan T2): state+id reach, the null-unconfigured
// path, the copy toggle, the 5-tap reveal within the window, and the outside-window reset. The
// `MainDispatcherRule` + `runTest` virtual scheduler becomes the cooperative pool: each
// `advanceUntilIdle()` is a `waitUntil` that yields the main actor until the named condition holds.
// `hotViewModel()` — a ViewModel with a live `state` subscriber — is spelled the same way, because
// `@Observable`'s observation starts in `init` rather than on first read, so every ViewModel is
// already "hot".
//
// The `FixedSalusClock` is advanced with `advanceTo(_:)` and the taps are fired at the new time,
// exactly as the Kotlin test's `tap(count:millis:)` helper does (`AboutViewModelTest.kt:69-74`).

import Foundation
import SalusCommon
import SalusPremium
import SalusTesting
import Testing

@testable import FeatureSettings

@Suite("AboutViewModel")
@MainActor
struct AboutViewModelTests {
    /// The fake gateway the Kotlin test holds as a field, rebuilt per case so no state leaks
    /// across them (`AboutViewModelTest.kt:33-46`).
    private final class FakePurchasesGateway: PurchasesGateway, @unchecked Sendable {
        var appUserID: String?
        let isConfigured = true
        var customerUpdates: AsyncStream<CustomerSnapshot> { AsyncStream { $0.finish() } }
        func currentCustomer() async -> CustomerSnapshot? {
            nil
        }
        func currentOffering() async -> PaywallOffering? {
            nil
        }
        func purchase(host: PurchaseHost, packageId: String) async -> PurchaseOutcome {
            .cancelled
        }
        func restore() async -> CustomerSnapshot {
            CustomerSnapshot(entitlementActive: false, hasBillingIssue: false)
        }
    }

    /// The fake premium repository the Kotlin test holds as a field (`AboutViewModelTest.kt:27-31`).
    private final class FakePremiumRepository: PremiumRepository, @unchecked Sendable {
        private let lock = NSLock()
        private var value: PremiumStatus
        private var continuations: [UUID: AsyncStream<PremiumStatus>.Continuation] = [:]

        init(value: PremiumStatus = .free) {
            self.value = value
        }

        var status: AsyncStream<PremiumStatus> {
            AsyncStream(bufferingPolicy: .bufferingNewest(1)) { continuation in
                let id = UUID()
                lock.lock()
                continuations[id] = continuation
                let current = value
                lock.unlock()

                continuation.yield(current)
                continuation.onTermination = { [weak self] _ in
                    self?.removeContinuation(id)
                }
            }
        }

        func refresh() async {}

        func setValue(_ newValue: PremiumStatus) {
            lock.lock()
            value = newValue
            let pending = Array(continuations.values)
            lock.unlock()
            for continuation in pending {
                continuation.yield(newValue)
            }
        }

        private func removeContinuation(_ id: UUID) {
            lock.lock()
            continuations[id] = nil
            lock.unlock()
        }
    }

    private func makeViewModel(
        appUserID: String? = nil,
        premiumStatus: PremiumStatus = .free
    ) -> (vm: AboutViewModel, gateway: FakePurchasesGateway, premium: FakePremiumRepository, clock: FixedSalusClock) {
        let gateway = FakePurchasesGateway()
        gateway.appUserID = appUserID
        let premium = FakePremiumRepository(value: premiumStatus)
        let clock = FixedSalusClock(now: Date(timeIntervalSince1970: 1000))
        let vm = AboutViewModel(gateway: gateway, premiumRepository: premium, clock: clock)
        return (vm, gateway, premium, clock)
    }

    /// Advances the fake clock by `millis` and fires `count` taps at that new time
    /// (`AboutViewModelTest.kt:69-74`).
    private func tap(_ vm: AboutViewModel, _ clock: FixedSalusClock, count: Int, millis: TimeInterval) {
        clock.advanceTo(clock.now().addingTimeInterval(millis))
        for _ in 0 ..< count {
            vm.onEvent(.titleTapped)
        }
    }

    @Test("state carries the app user id and the premium status")
    func stateCarriesTheAppUserIDAndThePremiumStatus() async {
        let fixture = makeViewModel(appUserID: "$RCAnonymousID:abc-123", premiumStatus: .premium)

        await waitUntil("the initial state to settle") {
            fixture.vm.state.appUserID == "$RCAnonymousID:abc-123"
                && fixture.vm.state.premiumStatus == .premium
        }

        #expect(fixture.vm.state.appUserID == "$RCAnonymousID:abc-123")
        #expect(fixture.vm.state.premiumStatus == .premium)
        #expect(fixture.vm.state.copied == false)
        #expect(fixture.vm.state.idRevealed == false)
    }

    @Test("the app user id is null when the gateway has none")
    func theAppUserIDIsNullWhenTheGatewayHasNone() async {
        let fixture = makeViewModel()

        await waitUntil("the initial state to settle") { fixture.vm.state.appUserID == nil }

        #expect(fixture.vm.state.appUserID == nil)
    }

    @Test("copying the support code flips the copied flag and then reverts it")
    func copyingTheSupportCodeFlipsTheCopiedFlagAndThenRevertsIt() async {
        let fixture = makeViewModel(appUserID: "$RCAnonymousID:abc-123")

        await waitUntil("the initial state to settle") { !fixture.vm.state.copied }
        #expect(fixture.vm.state.copied == false)

        fixture.vm.onEvent(.copySupportCode)
        await waitUntil("the copied flag to flip") { fixture.vm.state.copied }

        // The 2 s "Copied" label reverts after the window. The ViewModel's `Task.sleep` is real
        // wall-clock time (there is no virtual scheduler on iOS), so the test waits the same 2 s
        // the Kotlin test's `advanceTimeBy(2_001)` advances (`AboutViewModelTest.kt:110`).
        try? await Task.sleep(nanoseconds: 2_100_000_000)
        await waitUntil("the copied flag to revert") { !fixture.vm.state.copied }
        #expect(fixture.vm.state.copied == false)
    }

    @Test("five taps within the window reveal the support code")
    func fiveTapsWithinTheWindowRevealTheSupportCode() async {
        let fixture = makeViewModel(appUserID: "$RCAnonymousID:abc-123")

        await waitUntil("the initial state to settle") { !fixture.vm.state.idRevealed }
        #expect(fixture.vm.state.idRevealed == false)

        // Four taps, each 1 s apart — still within the 3 s window.
        for _ in 0 ..< 4 {
            tap(fixture.vm, fixture.clock, count: 1, millis: 1)
        }
        #expect(fixture.vm.state.idRevealed == false)

        // The fifth tap, 1 s after the fourth, completes the reveal.
        tap(fixture.vm, fixture.clock, count: 1, millis: 1)
        await waitUntil("the reveal to reach the state") { fixture.vm.state.idRevealed }
        #expect(fixture.vm.state.idRevealed)
    }

    @Test("a tap outside the window resets the count")
    func aTapOutsideTheWindowResetsTheCount() async {
        let fixture = makeViewModel(appUserID: "$RCAnonymousID:abc-123")

        await waitUntil("the initial state to settle") { !fixture.vm.state.idRevealed }

        // Four taps within the window.
        for _ in 0 ..< 4 {
            tap(fixture.vm, fixture.clock, count: 1, millis: 1)
        }
        #expect(fixture.vm.state.idRevealed == false)

        // The fifth tap arrives 4 s after the fourth — past the 3 s window, so the count resets.
        tap(fixture.vm, fixture.clock, count: 1, millis: 4)
        #expect(fixture.vm.state.idRevealed == false)

        // Five fresh taps within the window now reveal.
        for _ in 0 ..< 5 {
            tap(fixture.vm, fixture.clock, count: 1, millis: 1)
        }
        await waitUntil("the reveal to reach the state") { fixture.vm.state.idRevealed }
        #expect(fixture.vm.state.idRevealed)
    }
}
