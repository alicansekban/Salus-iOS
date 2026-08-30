// iOS-only, no Kotlin twin — the two cases that pin `MoreViewModel`'s effect **queue**
// (divergence 4 in `MoreViewModel.swift`).
//
// Android buffers effects in a `Channel` collected by a `LaunchedEffect` that never returns, so a
// second effect is delivered by construction and needs no test. iOS has no `Channel`: the effects
// accumulate in `pendingEffects`, which `MoreRoute` watches with
// `.onChange(of: viewModel.pendingEffects)`. The T6 fix round replaced a one-shot `.task` drain
// that ran a `while !pendingEffects.isEmpty` loop at appear — when the queue was still empty — and
// therefore stranded every effect a tap produced afterwards. These two cases pin the two
// properties that collector depends on: a drained queue refills on the next event, and two events
// fired back-to-back come out in order.
//
// They live beside `MoreViewModelTests` rather than in it so that suite stays the ported Kotlin
// table (and under the `type_body_length` gate).

import Testing

@testable import FeatureSettings

@Suite("MoreViewModel effect queue")
@MainActor
struct MoreEffectQueueTests {
    /// An entitled ViewModel — both effect-producing rows are behind the entitlement gate.
    private func makeEntitledViewModel() -> MoreViewModel {
        MoreViewModel(
            profileRepository: FakeProfileRepository(),
            premiumStatus: FakeMorePremiumStatus(value: .entitled),
            preferences: FakeSettingsPreferences(),
            localeController: FakeAppLocaleController(),
            paywallRequester: FakePaywallRequester()
        )
    }

    private func loaded() async -> MoreViewModel {
        let viewModel = makeEntitledViewModel()
        await waitUntil("the entitled state to load") {
            !viewModel.state.isLoading && viewModel.state.premiumStatus == .entitled
        }
        return viewModel
    }

    @Test("an effect fired after the first drain is queued again")
    func anEffectFiredAfterTheFirstDrainIsQueuedAgain() async {
        let viewModel = await loaded()

        // The appearance drain: nothing is pending yet, which is exactly the state the old
        // `while !pendingEffects.isEmpty` loop exited on and never re-entered.
        #expect(viewModel.consumeEffects().isEmpty)

        viewModel.onEvent(.premiumClicked)
        await waitUntil("the first effect") { !viewModel.pendingEffects.isEmpty }
        #expect(viewModel.consumeEffects() == [.openUrl("https://apps.apple.com/account/subscriptions")])
        #expect(viewModel.pendingEffects.isEmpty)

        // A second tap after the queue was drained — the case that was stranded.
        viewModel.onEvent(.trendsClicked)
        await waitUntil("the second effect") { !viewModel.pendingEffects.isEmpty }
        #expect(viewModel.consumeEffects() == [.openTrends])
    }

    @Test("two effects fired back to back are drained in order")
    func twoEffectsFiredBackToBackAreDrainedInOrder() async {
        let viewModel = await loaded()

        viewModel.onEvent(.doctorReportClicked)
        viewModel.onEvent(.trendsClicked)
        await waitUntil("both effects") { viewModel.pendingEffects.count == 2 }

        #expect(viewModel.consumeEffects() == [.openDoctorReport, .openTrends])
    }
}
