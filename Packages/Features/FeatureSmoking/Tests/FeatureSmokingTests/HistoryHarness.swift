// The state every `SmokingHistoryViewModel` suite shares, the twin of the fixtures at the top of
// `SmokingHistoryViewModelTest.kt`: one fixed clock at 2026-03-10T12:00 Europe/Istanbul, one fake
// store, the real calculator over it and the real `EditEvent` / `DeleteEvent`. Rebuilt per case.

import Foundation
import SalusCommon
import SalusSmoking
import SalusTesting
import Testing

@testable import FeatureSmoking

@MainActor
struct HistoryHarness {
    let nowMs: Int64 = 1_773_133_200_000 // 2026-03-10T12:00 Europe/Istanbul
    let zone = FixedSalusClock.defaultZone
    let clock = FixedSalusClock(now: Date(timeIntervalSince1970: 1_773_133_200))
    let store: FakeSmokingStore

    init(_ input: SmokingInput) {
        store = FakeSmokingStore(initial: input)
    }

    /// A QUIT plan whose attempt began 42 days before now unless `attempts` says otherwise.
    init(events: [SmokingEvent] = [], attempts: [QuitAttempt]? = nil) {
        self.init(Self.quitInput(events: events, attempts: attempts))
    }

    func viewModel() -> SmokingHistoryViewModel {
        SmokingHistoryViewModel(
            repository: FakeSmokingRepository(store: store, clock: clock),
            editEvent: EditEvent(store: store),
            deleteEvent: DeleteEvent(store: store),
            clock: clock
        )
    }

    /// A view model that has taken its first rows — Android's `advanceUntilIdle()` after
    /// construction.
    func loadedViewModel() async -> SmokingHistoryViewModel {
        let vm = viewModel()
        await waitUntil("the first rows") { vm.state.loaded }
        return vm
    }

    // MARK: Time

    /// "2026-03-10T09:15" in Europe/Istanbul, which holds +03:00 all of 2026.
    func ms(_ local: String) -> Int64 {
        guard let date = try? Date("\(local):00+03:00", strategy: .iso8601) else {
            Issue.record("unparsable fixture time \(local)")
            return 0
        }
        return Int64((date.timeIntervalSince1970 * 1000).rounded())
    }

    func dayOf(_ ms: Int64) -> Int64 {
        epochDay(of: ms, in: zone)
    }

    // MARK: Rows

    func plan(_ mode: SmokingMode = .quit) -> SmokingPlan {
        Self.plan(mode, nowMs: nowMs, zoneId: zone.identifier)
    }

    func smoked(
        _ id: String,
        at local: String,
        units: Int64 = 1,
        trigger: CravingTrigger? = nil,
        intensity: Int? = nil,
        attempt: String? = "attempt-1"
    ) -> SmokingEvent {
        let atMs = ms(local)
        return SmokingEvent(
            id: id,
            type: .smoked,
            occurredAtMs: atMs,
            tzId: zone.identifier,
            epochDay: dayOf(atMs),
            units: units,
            trigger: trigger,
            intensity: intensity,
            productType: .cigarette,
            attemptId: attempt
        )
    }

    func craving(
        _ id: String,
        at local: String,
        trigger: CravingTrigger? = nil,
        attempt: String? = "attempt-1"
    ) -> SmokingEvent {
        let atMs = ms(local)
        return SmokingEvent(
            id: id,
            type: .cravingResisted,
            occurredAtMs: atMs,
            tzId: zone.identifier,
            epochDay: dayOf(atMs),
            units: nil,
            trigger: trigger,
            intensity: nil,
            productType: .cigarette,
            attemptId: attempt
        )
    }

    static let prices = [PricePeriod(id: "price-1", effectiveFromEpochDay: 0, unitCostMinor: 475)]

    static func quitInput(events: [SmokingEvent], attempts: [QuitAttempt]?) -> SmokingInput {
        let nowMs: Int64 = 1_773_133_200_000
        let zoneId = FixedSalusClock.defaultZone.identifier
        return SmokingInput(
            plan: plan(.quit, nowMs: nowMs, zoneId: zoneId),
            prices: prices,
            attempts: attempts ?? [
                QuitAttempt(
                    id: "attempt-1",
                    startedAtMs: nowMs - 42 * dayMs,
                    tzId: zoneId,
                    endedAtMs: nil,
                    endReason: nil
                )
            ],
            events: events,
            goal: nil
        )
    }

    static func plan(_ mode: SmokingMode, nowMs: Int64, zoneId: String) -> SmokingPlan {
        SmokingPlan(
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
        )
    }
}
