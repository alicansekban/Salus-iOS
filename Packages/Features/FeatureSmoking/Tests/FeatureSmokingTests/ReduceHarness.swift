// The REDUCE twin of ``MainHarness``: one fake store holding a REDUCE plan (limit 10, old average
// 20) at 2026-03-10T12:00 Europe/Istanbul unless a test starts elsewhere in the day.

import Foundation
import SalusCommon
import SalusNavigation
import SalusSmoking
import SalusTesting
import SalusUI
import Testing

@testable import FeatureSmoking

@MainActor
struct ReduceHarness {
    let noon: Int64 = 1_773_133_200_000 // 2026-03-10T12:00 Europe/Istanbul
    let zone = FixedSalusClock.defaultZone
    let clock: FixedSalusClock
    let navigator = FakeNavigator()
    let ids = CountingIds()
    let snackbar = SalusSnackbarController()
    let store: FakeSmokingStore

    init(atMs: Int64? = nil, mode: SmokingMode = .reduce, attempts: [QuitAttempt] = []) {
        let noon: Int64 = 1_773_133_200_000
        let zoneId = FixedSalusClock.defaultZone.identifier
        clock = FixedSalusClock(now: Date(timeIntervalSince1970: Double(atMs ?? noon) / 1000))
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
                    createdAtMs: noon - 30 * dayMs,
                    tzId: zoneId
                ),
                prices: [PricePeriod(id: "price-1", effectiveFromEpochDay: 0, unitCostMinor: 475)],
                attempts: attempts,
                events: [],
                goal: nil
            )
        )
    }

    func viewModel() -> SmokingMainViewModel {
        makeMainViewModel(store: store, clock: clock, ids: ids, snackbar: snackbar, navigator: navigator)
    }

    /// A viewmodel that has taken its first snapshot.
    func subscribedViewModel() async -> SmokingMainViewModel {
        let vm = viewModel()
        await waitUntil("the first snapshot") { vm.state.snapshot != nil }
        return vm
    }

    /// An attempt a switch to REDUCE closed at `endedAtMs`.
    func closedAttempt(endedAtMs: Int64) -> QuitAttempt {
        QuitAttempt(
            id: "attempt-old",
            startedAtMs: endedAtMs - 10 * dayMs,
            tzId: zone.identifier,
            endedAtMs: endedAtMs,
            endReason: .switchedToReduce
        )
    }
}

extension SmokingMainViewModel {
    /// The REDUCE snapshot the state carries; the test fails if there is none.
    func reduce() throws -> ReduceSnapshot {
        guard case let .reduce(snapshot) = state.snapshot else {
            throw ReduceHarnessError.notReduce
        }
        return snapshot
    }
}

enum ReduceHarnessError: Error {
    case notReduce
}
