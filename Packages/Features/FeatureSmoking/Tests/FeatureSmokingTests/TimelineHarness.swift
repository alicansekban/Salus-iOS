// The state every `SmokingTimelineViewModel` suite shares, the twin of the fixtures at the top of
// `SmokingTimelineViewModelTest.kt`: one fixed clock at 2026-03-10T12:00 Europe/Istanbul, one fake
// store, the real calculator over it and the real `SwitchMode`. Rebuilt per case.

import Foundation
import SalusCommon
import SalusSmoking
import SalusTesting
import Testing

@testable import FeatureSmoking

@MainActor
struct TimelineHarness {
    let nowMs: Int64 = 1_773_133_200_000 // 2026-03-10T12:00 Europe/Istanbul
    let zoneId = FixedSalusClock.defaultZone.identifier
    let clock = FixedSalusClock(now: Date(timeIntervalSince1970: 1_773_133_200))
    let ids = CountingIds()
    let store: FakeSmokingStore

    /// A QUIT attempt that began `agoMs` before now, with the last slip `slipAgoMs` before now.
    init(agoMs: Int64, slipAgoMs: Int64? = nil, product: ProductType = .cigarette) {
        let nowMs: Int64 = 1_773_133_200_000
        let zoneId = FixedSalusClock.defaultZone.identifier
        store = FakeSmokingStore(
            initial: SmokingInput(
                plan: Self.plan(mode: .quit, product: product, nowMs: nowMs, zoneId: zoneId),
                prices: Self.prices,
                attempts: [QuitAttempt(
                    id: "attempt-1",
                    startedAtMs: nowMs - agoMs,
                    tzId: zoneId,
                    endedAtMs: nil,
                    endReason: nil
                )],
                events: slipAgoMs.map { [Self.slip(atMs: nowMs - $0, zoneId: zoneId)] } ?? [],
                goal: nil
            )
        )
    }

    /// A REDUCE plan, whose earlier quit attempt closed `closedAgoMs` before now when one is given.
    init(reduceClosedAgoMs closedAgoMs: Int64? = nil) {
        let nowMs: Int64 = 1_773_133_200_000
        let zoneId = FixedSalusClock.defaultZone.identifier
        store = FakeSmokingStore(
            initial: SmokingInput(
                plan: Self.plan(mode: .reduce, product: .cigarette, nowMs: nowMs, zoneId: zoneId),
                prices: Self.prices,
                attempts: closedAgoMs.map {
                    [QuitAttempt(
                        id: "attempt-0",
                        startedAtMs: nowMs - 100 * dayMs,
                        tzId: zoneId,
                        endedAtMs: nowMs - $0,
                        endReason: .switchedToReduce
                    )]
                } ?? [],
                events: [],
                goal: nil
            )
        )
    }

    func viewModel(highlightStageId: String? = nil) -> SmokingTimelineViewModel {
        SmokingTimelineViewModel(
            highlightStageId: highlightStageId,
            repository: FakeSmokingRepository(store: store, clock: clock),
            switchMode: SwitchMode(store: store, clock: clock, idGenerator: ids),
            clock: clock
        )
    }

    /// A view model that has taken its first snapshot — Android's `advanceUntilIdle()` after
    /// construction.
    func loadedViewModel(highlightStageId: String? = nil) async -> SmokingTimelineViewModel {
        let vm = viewModel(highlightStageId: highlightStageId)
        await waitUntil("the first snapshot") { vm.state.mode != .none }
        return vm
    }

    private static let prices = [PricePeriod(id: "price-1", effectiveFromEpochDay: 0, unitCostMinor: 475)]

    private static func plan(mode: SmokingMode, product: ProductType, nowMs: Int64, zoneId: String) -> SmokingPlan {
        SmokingPlan(
            id: "plan-1",
            mode: mode,
            productType: product,
            baselineUnitsPerDay: 20,
            dailyLimit: mode == .reduce ? 10 : nil,
            currencyCode: "TRY",
            reason: nil,
            notificationsEnabled: true,
            eveningReminderEnabled: false,
            createdAtMs: nowMs - 400 * dayMs,
            tzId: zoneId
        )
    }

    private static func slip(atMs: Int64, zoneId: String) -> SmokingEvent {
        SmokingEvent(
            id: "slip-1",
            type: .smoked,
            occurredAtMs: atMs,
            tzId: zoneId,
            epochDay: atMs / dayMs,
            units: 1,
            trigger: nil,
            intensity: nil,
            productType: .cigarette,
            attemptId: "attempt-1"
        )
    }
}
