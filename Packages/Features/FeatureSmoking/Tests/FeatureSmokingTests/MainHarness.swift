// The state every `SmokingMainViewModel` suite shares: one fixed clock at 2026-03-10T12:00
// Europe/Istanbul, one fake store holding a QUIT attempt that began 42 days earlier, the real
// calculator over it, and a recording navigator. Rebuilt per case so nothing leaks across them.

import Foundation
import SalusCommon
import SalusNavigation
import SalusSmoking
import SalusTesting
import Testing

@testable import FeatureSmoking

let minuteMs: Int64 = 60000
let hourMs: Int64 = 60 * minuteMs
let dayMs: Int64 = 24 * hourMs

@MainActor
struct MainHarness {
    let nowMs: Int64 = 1_773_133_200_000 // 2026-03-10T12:00 Europe/Istanbul
    let zone = FixedSalusClock.defaultZone
    let clock = FixedSalusClock(now: Date(timeIntervalSince1970: 1_773_133_200))
    let navigator = FakeNavigator()
    let ids = CountingIds()
    let store: FakeSmokingStore

    init(agoMs: Int64 = 42 * dayMs, events: [SmokingEvent] = []) {
        let nowMs: Int64 = 1_773_133_200_000
        let zoneId = FixedSalusClock.defaultZone.identifier
        store = FakeSmokingStore(
            initial: SmokingInput(
                plan: SmokingPlan(
                    id: "plan-1",
                    mode: .quit,
                    productType: .cigarette,
                    baselineUnitsPerDay: 20,
                    dailyLimit: nil,
                    currencyCode: "TRY",
                    reason: nil,
                    notificationsEnabled: true,
                    eveningReminderEnabled: false,
                    createdAtMs: nowMs - 100 * dayMs,
                    tzId: zoneId
                ),
                prices: [PricePeriod(id: "price-1", effectiveFromEpochDay: 0, unitCostMinor: 475)],
                attempts: [
                    QuitAttempt(
                        id: "attempt-1",
                        startedAtMs: nowMs - agoMs,
                        tzId: zoneId,
                        endedAtMs: nil,
                        endReason: nil
                    )
                ],
                events: events,
                goal: nil
            )
        )
    }

    func viewModel() -> SmokingMainViewModel {
        SmokingMainViewModel(
            repository: FakeSmokingRepository(store: store, clock: clock),
            clock: clock,
            resolveSlip: ResolveSlip(store: store, clock: clock, idGenerator: ids),
            editEvent: EditEvent(store: store),
            navigator: navigator.navigator
        )
    }

    /// A viewmodel that has taken its first snapshot — Android's `subscribe(vm)`.
    func subscribedViewModel() async -> SmokingMainViewModel {
        let vm = viewModel()
        await waitUntil("the first snapshot") { vm.state.snapshot != nil }
        return vm
    }

    func craving(id: String, atMs: Int64) -> SmokingEvent {
        SmokingEvent(
            id: id,
            type: .cravingResisted,
            occurredAtMs: atMs,
            tzId: zone.identifier,
            epochDay: atMs / dayMs,
            units: nil,
            trigger: nil,
            intensity: nil,
            productType: .cigarette,
            attemptId: "attempt-1"
        )
    }
}

extension SmokingMainViewModel {
    /// The QUIT snapshot the state carries; the test fails if there is none.
    func quit() throws -> QuitSnapshot {
        guard case let .quit(snapshot) = state.snapshot else {
            throw MainHarnessError.notQuit
        }
        return snapshot
    }
}

enum MainHarnessError: Error {
    case notQuit
}
