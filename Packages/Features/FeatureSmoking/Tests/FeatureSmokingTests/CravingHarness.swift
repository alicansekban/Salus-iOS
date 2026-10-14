// The state every `CravingViewModel` case shares, the twin of the Kotlin test's `Fixture`: one fixed
// clock at 2026-03-10T12:00 Europe/Istanbul, a fake store holding a QUIT attempt that began 42 days
// earlier with two cravings already beaten (or a REDUCE plan), the real calculator over it, and a
// recording navigator.
//
// The clock never moves by itself, so a case that wants time to pass says so: `advance(bySeconds:)`
// moves the fixed clock, and the ViewModel only learns of it through `refreshClock()` — which is
// also all the screen's ticker does.

import Foundation
import SalusCommon
import SalusNavigation
import SalusSmoking
import SalusTesting
import Testing

@testable import FeatureSmoking

@MainActor
struct CravingHarness {
    let nowMs: Int64 = 1_773_133_200_000 // 2026-03-10T12:00 Europe/Istanbul
    let zone = FixedSalusClock.defaultZone
    let clock = FixedSalusClock(now: Date(timeIntervalSince1970: 1_773_133_200))
    let navigator = FakeNavigator()
    let ids = CountingIds()
    let store: FakeSmokingStore

    /// The two cravings the QUIT fixture starts with: the ones a new craving is counted after.
    static let oldCravingIds: Set = ["old-0", "old-1"]

    init(
        mode: SmokingMode = .quit,
        reason: String? = nil,
        earlierAttemptCravings: Int = 0,
        extraEvents: [SmokingEvent] = []
    ) {
        let nowMs: Int64 = 1_773_133_200_000
        let zoneId = FixedSalusClock.defaultZone.identifier
        let isQuit = mode == .quit
        store = FakeSmokingStore(
            initial: SmokingInput(
                plan: SmokingPlan(
                    id: "plan-1",
                    mode: mode,
                    productType: .cigarette,
                    baselineUnitsPerDay: 20,
                    dailyLimit: isQuit ? nil : 10,
                    currencyCode: "TRY",
                    reason: reason,
                    notificationsEnabled: true,
                    eveningReminderEnabled: false,
                    createdAtMs: nowMs - 100 * dayMs,
                    tzId: zoneId
                ),
                prices: [PricePeriod(id: "price-1", effectiveFromEpochDay: 0, unitCostMinor: 475)],
                attempts: isQuit
                    ? [
                        // The attempt a restart closed, when a case wants cravings that are not this
                        // attempt's.
                        earlierAttemptCravings > 0
                            ? QuitAttempt(
                                id: "attempt-0",
                                startedAtMs: nowMs - 100 * dayMs,
                                tzId: zoneId,
                                endedAtMs: nowMs - 43 * dayMs,
                                endReason: .restarted
                            )
                            : nil,
                        QuitAttempt(
                            id: "attempt-1",
                            startedAtMs: nowMs - 42 * dayMs,
                            tzId: zoneId,
                            endedAtMs: nil,
                            endReason: nil
                        )
                    ].compactMap(\.self)
                    : [],
                events: (isQuit ? (0 ..< 2).map { Self.craving(id: "old-\($0)", attemptId: "attempt-1") } : [])
                    + (0 ..< earlierAttemptCravings).map {
                        Self.craving(id: "earlier-\($0)", attemptId: "attempt-0", atMs: nowMs - 90 * dayMs)
                    }
                    + extraEvents,
                goal: nil
            )
        )
    }

    /// A craving beaten a day before the fixture's "now", unless `atMs` says otherwise.
    static func craving(id: String, attemptId: String?, atMs: Int64 = 1_773_133_200_000 - dayMs) -> SmokingEvent {
        SmokingEvent(
            id: id,
            type: .cravingResisted,
            occurredAtMs: atMs,
            tzId: FixedSalusClock.defaultZone.identifier,
            epochDay: atMs / dayMs,
            units: nil,
            trigger: nil,
            intensity: nil,
            productType: .cigarette,
            attemptId: attemptId
        )
    }

    func viewModel() -> CravingViewModel {
        makeCravingViewModel(store: store, clock: clock, ids: ids, navigator: navigator)
    }

    /// A ViewModel that has taken its first snapshot — Android's `ready()`.
    func readyViewModel() async -> CravingViewModel {
        let vm = viewModel()
        await waitUntil("the first snapshot") { vm.state.mode != nil }
        return vm
    }

    /// Moves the fixed clock `seconds` past where the screen began. The ViewModel has not looked yet.
    func advance(bySeconds seconds: Int64) {
        clock.advanceTo(Date(timeIntervalSince1970: Double(nowMs) / 1000 + Double(seconds)))
    }

    /// The cravings the screen wrote, not the two the fixture began with.
    var resisted: [SmokingEvent] {
        store.input.events.filter { $0.type == .cravingResisted && !Self.oldCravingIds.contains($0.id) }
    }

    var smoked: [SmokingEvent] {
        store.input.events.filter { $0.type == .smoked }
    }
}

/// The ViewModel over the real use cases and a fake store.
@MainActor
func makeCravingViewModel(
    store: FakeSmokingStore,
    clock: FixedSalusClock,
    ids: CountingIds,
    navigator: FakeNavigator
) -> CravingViewModel {
    CravingViewModel(
        repository: FakeSmokingRepository(store: store, clock: clock),
        clock: clock,
        logCravingResisted: LogCravingResisted(store: store, clock: clock, idGenerator: ids),
        logSmoked: LogSmoked(store: store, clock: clock, idGenerator: ids),
        resolveSlip: ResolveSlip(store: store, clock: clock, idGenerator: ids),
        editEvent: EditEvent(store: store),
        navigator: navigator.navigator
    )
}
