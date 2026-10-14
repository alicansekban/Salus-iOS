// The savings-goal twin of ``MainHarness``: the same QUIT plan 42 days into an attempt (20 a day at
// 4.75, so a goal made ten days ago stands at 950.00 saved), with a goal row, a premium status and a
// paywall controller. Mirrors the `fixture(…)` of Android's `SmokingMainGoalViewModelTest`.

import Foundation
import SalusCommon
import SalusPremium
import SalusSmoking
import SalusTesting
import SalusUI
import Testing

@testable import FeatureSmoking

@MainActor
struct GoalHarness {
    /// 2026-03-10T12:00 Europe/Istanbul.
    static let noon: Int64 = 1_773_133_200_000

    let nowMs = GoalHarness.noon
    let clock = FixedSalusClock(now: Date(timeIntervalSince1970: 1_773_133_200))
    let navigator = FakeNavigator()
    let ids = CountingIds()
    let snackbar = SalusSnackbarController()
    let paywall = PaywallController()
    let premium: FakePremiumRepository
    let store: FakeSmokingStore

    init(goal: SavingsGoal?, mode: SmokingMode = .quit, status: PremiumStatus = .premium) {
        let nowMs = GoalHarness.noon
        let zoneId = FixedSalusClock.defaultZone.identifier
        premium = FakePremiumRepository(value: status)
        store = FakeSmokingStore(
            initial: SmokingInput(
                plan: SmokingPlan(
                    id: "plan-1",
                    mode: mode,
                    productType: .cigarette,
                    baselineUnitsPerDay: 20,
                    dailyLimit: mode == .reduce ? 10 : nil,
                    currencyCode: "TRY",
                    reason: nil,
                    notificationsEnabled: true,
                    eveningReminderEnabled: false,
                    createdAtMs: nowMs - 100 * dayMs,
                    tzId: zoneId
                ),
                prices: [PricePeriod(id: "price-1", effectiveFromEpochDay: 0, unitCostMinor: 475)],
                attempts: mode == .quit
                    ? [QuitAttempt(
                        id: "attempt-1",
                        startedAtMs: nowMs - 42 * dayMs,
                        tzId: zoneId,
                        endedAtMs: nil,
                        endReason: nil
                    )]
                    : [],
                events: [],
                goal: goal
            )
        )
    }

    /// A goal made ten days ago.
    static func goal(target: Int64, achievedAtMs: Int64? = nil) -> SavingsGoal {
        SavingsGoal(
            id: "goal-1",
            title: "Yeni bisiklet",
            targetMinor: target,
            createdAtMs: noon - 10 * dayMs,
            achievedAtMs: achievedAtMs
        )
    }

    func viewModel() -> SmokingMainViewModel {
        makeMainViewModel(
            store: store,
            clock: clock,
            ids: ids,
            snackbar: snackbar,
            navigator: navigator,
            premium: premium,
            paywall: paywall
        )
    }

    /// A viewmodel that has taken its first snapshot and the premium status the account started with.
    func subscribedViewModel(status: PremiumStatus = .premium) async -> SmokingMainViewModel {
        let vm = viewModel()
        await waitUntil("the first snapshot") { vm.state.snapshot != nil }
        await waitUntil("the premium status") { vm.state.isPremium == status.isEntitled }
        return vm
    }

    /// Lets every task that is already runnable run, for a "nothing happened" expectation.
    func settle() async {
        for _ in 0 ..< 100 {
            await Task.yield()
        }
    }
}
