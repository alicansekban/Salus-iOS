// The state every `SmokingSettingsViewModel` suite shares, the twin of the fixtures at the top of
// `SmokingSettingsViewModelTest.kt`: one fixed clock at 2026-03-10T12:00 Europe/Istanbul, one fake
// store, the real calculator and use cases over it, a recording navigator and a stand-in for the
// notification authorization. Rebuilt per case.

import Foundation
import SalusCommon
import SalusReminder
import SalusSmoking
import SalusTesting
import Testing

@testable import FeatureSmoking

/// `ReminderEnvironment` with the one answer this screen asks for.
struct StubReminderEnvironment: ReminderEnvironment {
    var notifications: Bool

    func notificationsAuthorized() async -> Bool {
        notifications
    }

    func alarmKitAuthorized() async -> Bool {
        false
    }

    func backgroundRefreshAvailable() -> Bool {
        true
    }
}

@MainActor
struct SettingsHarness {
    let nowMs: Int64 = 1_773_133_200_000 // 2026-03-10T12:00 Europe/Istanbul
    let zone = FixedSalusClock.defaultZone
    let clock = FixedSalusClock(now: Date(timeIntervalSince1970: 1_773_133_200))
    let navigator = FakeNavigator()
    let ids = CountingIds()
    let store: FakeSmokingStore
    let repository: FakeSmokingRepository
    let environment: StubReminderEnvironment

    /// 2026-03-10 as an epoch day.
    let today: Int64 = 20522

    init(_ input: SmokingInput? = nil, notificationsAuthorized: Bool = true) {
        let clock = FixedSalusClock(now: Date(timeIntervalSince1970: 1_773_133_200))
        store = FakeSmokingStore(initial: input ?? Self.quitInput())
        repository = FakeSmokingRepository(store: store, clock: clock)
        environment = StubReminderEnvironment(notifications: notificationsAuthorized)
    }

    func viewModel() -> SmokingSettingsViewModel {
        SmokingSettingsViewModel(
            repository: repository,
            updatePrice: UpdatePrice(store: store, clock: clock, idGenerator: ids),
            updateCurrency: UpdateCurrency(store: store),
            updatePlanFields: UpdatePlanFields(store: store),
            editQuitDate: EditQuitDate(store: store, clock: clock),
            switchMode: SwitchMode(store: store, clock: clock, idGenerator: ids),
            resetSmoking: ResetSmoking(store: store),
            environment: environment,
            clock: clock,
            navigator: navigator.navigator
        )
    }

    /// A view model that has taken its first snapshot — Android's `advanceUntilIdle()` after
    /// construction.
    func loadedViewModel() async -> SmokingSettingsViewModel {
        let vm = viewModel()
        await waitUntil("the first snapshot") { vm.state.loaded }
        return vm
    }

    // MARK: Fixtures

    static let nowMs: Int64 = 1_773_133_200_000
    static let zoneId = FixedSalusClock.defaultZone.identifier

    static func plan(
        _ mode: SmokingMode = .quit,
        product: ProductType = .cigarette,
        reason: String? = nil,
        notifications: Bool = false,
        evening: Bool = false
    ) -> SmokingPlan {
        SmokingPlan(
            id: "plan-1",
            mode: mode,
            productType: product,
            baselineUnitsPerDay: 20,
            dailyLimit: mode == .reduce ? 10 : nil,
            currencyCode: "TRY",
            reason: reason,
            notificationsEnabled: notifications,
            eveningReminderEnabled: evening,
            createdAtMs: nowMs - 100 * dayMs,
            tzId: zoneId
        )
    }

    static let prices = [
        PricePeriod(id: "price-old", effectiveFromEpochDay: 20522 - 100, unitCostMinor: 400),
        PricePeriod(id: "price-now", effectiveFromEpochDay: 20522 - 10, unitCostMinor: 475)
    ]

    /// A smoked entry `agoMs` before now, on the attempt it falls in.
    static func slip(_ id: String, agoMs: Int64, attempt: String? = "attempt-1") -> SmokingEvent {
        let atMs = nowMs - agoMs
        return SmokingEvent(
            id: id,
            type: .smoked,
            occurredAtMs: atMs,
            tzId: zoneId,
            epochDay: epochDay(of: atMs, in: FixedSalusClock.defaultZone),
            units: 1,
            trigger: nil,
            intensity: nil,
            productType: .cigarette,
            attemptId: attempt
        )
    }

    /// A QUIT plan whose active attempt began 42 days ago unless `attempts` says otherwise.
    static func quitInput(
        plan: SmokingPlan = plan(),
        events: [SmokingEvent] = [],
        attempts: [QuitAttempt]? = nil
    ) -> SmokingInput {
        SmokingInput(
            plan: plan,
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

    /// A REDUCE plan whose earlier quit attempt closed 60 days ago.
    static func reduceInput(plan: SmokingPlan = plan(.reduce), events: [SmokingEvent] = []) -> SmokingInput {
        SmokingInput(
            plan: plan,
            prices: prices,
            attempts: [
                QuitAttempt(
                    id: "attempt-0",
                    startedAtMs: nowMs - 80 * dayMs,
                    tzId: zoneId,
                    endedAtMs: nowMs - 60 * dayMs,
                    endReason: .switchedToReduce
                )
            ],
            events: events,
            goal: nil
        )
    }
}
