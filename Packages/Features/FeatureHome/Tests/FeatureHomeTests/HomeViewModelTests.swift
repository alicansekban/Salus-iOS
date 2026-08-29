// Ported from `feature/home/src/test/kotlin/com/alicansekban/salus/feature/home/ui/
// HomeViewModelTest.kt` — all four cases, by name, in the Kotlin order, with two iOS-only cases
// after them (listed separately in the task report).
//
// Three mechanical differences from the Kotlin, all already settled elsewhere in this port:
// Turbine's `state.test { awaitItem() }` becomes reading `viewModel.state` after `waitUntil`,
// because the iOS state is an `@Observable` property rather than a `StateFlow`; Kotlin's
// `while (state.isLoading) state = awaitItem()` is ``loadedState(_:)``, which every case therefore
// still makes; and `MainDispatcherRule` has no twin — `@MainActor` on the suite is the whole
// mechanism.
//
// **One Kotlin fake has no iOS surface and that is the point.** `HomeViewModelTest.kt:76-80` gives
// its `AiSummaryRepository` a `getSummary` that throws `AssertionError("Home must never request a
// summary")`, because Android's `HomeViewModel` takes the whole repository and could call it. iOS
// narrows the dependency to ``HomeAiSummaryAvailability``, a protocol with one property and no
// `getSummary` at all, so the contract is enforced by the type system rather than by a fake that
// must be reached to fail. There is nothing to port and nothing is lost.
//
// **Case 4 is ported whole**, not split. The research notes flagged it as partially deferred to
// iOS-M9 because iOS has no `PremiumRepository` yet; plan ruling 1 answers that by carrying
// ``HomePremiumStatus`` from day one, so a fake that emits `true` proves the ViewModel's arm exactly
// as `PremiumStatus.PREMIUM` does on Android. What is deferred is the *production* binding
// (`FreeOnlyPremiumStatus`, divergence (d)), not the case.
//
// The two iOS-only cases cover what plan ruling 3 replaced `SharingStarted.WhileSubscribed(5_000)`
// with, and the greeting table Kotlin never asserts:
//   - `restartObservation()` re-runs `observeTodayOverview()`, which re-captures the clock, so a
//     dashboard left open over midnight reports the new day only after the screen reappears;
//   - the four greeting buckets at each of their eight boundaries plus one interior hour.

import Foundation
import SalusCommon
import SalusModel
import SalusTesting
import Testing

@testable import FeatureHome

@Suite("HomeViewModel")
@MainActor
struct HomeViewModelTests {
    /// `HomeViewModelTest.kt:58` — 1_760_000_000_000 ms, which is 2025-10-09T08:53:20Z and so
    /// 11:53 in `FixedSalusClock`'s own Europe/Istanbul.
    private static let now = Date(timeIntervalSince1970: 1_760_000_000)

    /// `HomeViewModelTest.kt:41-51` — one pending "Aspirin" at 08:00, no appointments, cycle day 12
    /// and 80 kg.
    private static let overview = TodayOverview(
        doses: [
            TodayDose(
                scheduleId: "sch-1",
                medicationId: "med-1",
                medicationName: "Aspirin",
                minuteOfDay: 480,
                doseAmount: 1.0,
                status: .pending
            )
        ],
        appointments: [],
        cycle: CycleSnapshot(cycleDay: 12, isPeriodOpen: false),
        vitals: VitalsSnapshot(
            latestWeightKg: 80.0,
            weightTrend: [81, 80.5, 80],
            latestSystolic: 120.0,
            latestDiastolic: 80.0,
            latestGlucoseMgdl: 99.0,
            glucoseUnit: .mgDl
        )
    )

    private let clock = FixedSalusClock(now: HomeViewModelTests.now)
    private let repository = FakeTodayRepository(HomeViewModelTests.overview)
    /// `HomeViewModelTest.kt:72` — the free credit starts unspent.
    private let freeAiCredit = FakeHomeAiSummaryAvailability(available: true)
    /// `HomeViewModelTest.kt:82` — `PremiumStatus.FREE`.
    private let premiumStatus = FakeHomePremiumStatus(isPremium: false)
    private let doseActions = RecordingDoseActions()

    /// `HomeViewModelTest.kt:90-96`.
    private func viewModel(clock: FixedSalusClock? = nil) -> HomeViewModel {
        HomeViewModel(
            repository: repository,
            aiSummaryAvailability: freeAiCredit,
            premiumStatus: premiumStatus,
            clock: clock ?? self.clock,
            doseActions: doseActions
        )
    }

    /// Turbine's `while (state.isLoading) state = awaitItem()` (`HomeViewModelTest.kt:103-104`).
    private func loadedState(_ viewModel: HomeViewModel) async -> HomeUiState {
        #expect(viewModel.state.isLoading, "the state before the first triple is the default")
        await waitUntil("the first loaded state") { !viewModel.state.isLoading }
        return viewModel.state
    }

    // MARK: - The four Kotlin cases

    /// `HomeViewModelTest.kt:99-113`.
    @Test("state mirrors the repository overview")
    func stateMirrorsTheRepositoryOverview() async {
        let viewModel = viewModel()

        let state = await loadedState(viewModel)

        #expect(!state.isLoading)
        #expect(state.doses.count == 1)
        #expect(state.doses.first?.medicationName == "Aspirin")
        #expect(state.cycle?.cycleDay == 12)
        #expect(state.vitals?.latestWeightKg == 80.0)
        #expect(state.todayEpochDay == clock.todayEpochDay())
    }

    /// `HomeViewModelTest.kt:115-130`.
    @Test("repository updates flow through to the state")
    func repositoryUpdatesFlowThroughToTheState() async {
        let viewModel = viewModel()

        let state = await loadedState(viewModel)
        #expect(state.doses.first?.status == .pending)

        let taken = TodayOverview(
            doses: repository.current.doses.map { dose in
                TodayDose(
                    scheduleId: dose.scheduleId,
                    medicationId: dose.medicationId,
                    medicationName: dose.medicationName,
                    minuteOfDay: dose.minuteOfDay,
                    doseAmount: dose.doseAmount,
                    status: .taken
                )
            },
            appointments: repository.current.appointments,
            cycle: repository.current.cycle,
            vitals: repository.current.vitals
        )
        repository.set(taken)

        await waitUntil("the updated dose status") { viewModel.state.doses.first?.status == .taken }
        #expect(viewModel.state.doses.count == 1)
    }

    /// `HomeViewModelTest.kt:132-143`.
    @Test("take dose event routes to the shared write path with today's date")
    func takeDoseEventRoutesToTheSharedWritePathWithTodaysDate() async {
        let viewModel = viewModel()

        viewModel.onEvent(.takeDose(scheduleId: "sch-1", minuteOfDay: 480))

        await waitUntil("the recorded write") { !doseActions.taken.isEmpty }
        #expect(
            doseActions.taken == [
                RecordingDoseActions.RecordedDose(
                    scheduleId: "sch-1",
                    epochDay: clock.todayEpochDay(),
                    minuteOfDay: 480
                )
            ]
        )
    }

    /// `HomeViewModelTest.kt:145-162`.
    @Test("AI card flags follow the free credit and the entitlement")
    func aiCardFlagsFollowTheFreeCreditAndTheEntitlement() async {
        let viewModel = viewModel()

        let state = await loadedState(viewModel)
        #expect(state.freeAiSummaryAvailable)
        #expect(!state.isPremium)

        premiumStatus.set(true)
        await waitUntil("the entitlement to reach the state") { viewModel.state.isPremium }

        freeAiCredit.set(false)
        await waitUntil("the spent free credit to reach the state") { !viewModel.state.freeAiSummaryAvailable }
        // Still entitled: the two flags are independent arms of the same triple.
        #expect(viewModel.state.isPremium)
    }

    // MARK: - iOS-only

    /// iOS-only (plan ruling 3). No Kotlin twin: Android's
    /// `.stateIn(scope, SharingStarted.WhileSubscribed(5_000), HomeUiState())` re-runs the whole
    /// `combine` — and with it `observeTodayOverview()`'s eager clock capture — five seconds after
    /// the last collector leaves, which no unit test in that module exercises. `@Observable` has no
    /// subscription-count hook, so the iOS twin is `restartObservation()` called from `HomeRoute`'s
    /// `.task`; this pins that it is the *restart* that moves the day, not the passage of time.
    @Test("restart observation re-captures today after midnight")
    func restartObservationRecapturesTodayAfterMidnight() async {
        let viewModel = viewModel()
        let today = clock.todayEpochDay()

        let state = await loadedState(viewModel)
        #expect(state.todayEpochDay == today)

        clock.advanceTo(Self.now.addingTimeInterval(2 * 24 * 60 * 60))
        #expect(viewModel.state.todayEpochDay == today, "a clock that moved alone publishes nothing")

        viewModel.restartObservation()

        await waitUntil("the re-captured day") { viewModel.state.todayEpochDay == today + 2 }
    }

    /// iOS-only. `HomeViewModel.kt:62-67`'s buckets — `5..11`, `12..17`, `18..22`, else — asserted
    /// at both ends of each and at the two hours the `else` arm has to catch on either side of
    /// midnight. Kotlin has no case for `greetingFor`; the function is private there and reached
    /// only through the `combine`, so the table is written into the ViewModel and asserted nowhere.
    ///
    /// Driven through the clock rather than by calling the bucket function, so what is pinned is the
    /// hour the ViewModel actually reads (`clock.minuteOfDayNow() / 60`) and not just the `switch`.
    @Test("greeting follows the hour of day", arguments: HomeGreetingSample.table)
    func greetingFollowsTheHourOfDay(sample: HomeGreetingSample) async {
        let atHour = FixedSalusClock(now: clock.instant(of: clock.today(), minuteOfDay: sample.hour * 60))

        let viewModel = viewModel(clock: atHour)

        let state = await loadedState(viewModel)
        #expect(state.greeting == sample.greeting, "hour \(sample.hour)")
    }
}

/// One row of the greeting table.
struct HomeGreetingSample: Sendable {
    let hour: Int
    let greeting: HomeGreeting

    /// The four buckets at both of their ends, plus 23/0/4 for the `else` arm.
    static let table: [HomeGreetingSample] = [
        HomeGreetingSample(hour: 5, greeting: .morning),
        HomeGreetingSample(hour: 11, greeting: .morning),
        HomeGreetingSample(hour: 12, greeting: .afternoon),
        HomeGreetingSample(hour: 17, greeting: .afternoon),
        HomeGreetingSample(hour: 18, greeting: .evening),
        HomeGreetingSample(hour: 22, greeting: .evening),
        HomeGreetingSample(hour: 23, greeting: .night),
        HomeGreetingSample(hour: 0, greeting: .night),
        HomeGreetingSample(hour: 4, greeting: .night)
    ]
}

/// The twin of `HomeViewModelTest.kt:72-80`'s `MutableStateFlow(true)` plus the anonymous
/// `AiSummaryRepository` that exposes it — minus the `getSummary` that throws, which iOS's narrower
/// protocol makes unreachable (see the file header).
final class FakeHomeAiSummaryAvailability: HomeAiSummaryAvailability {
    private let flag: SettableFlag

    init(available: Bool) {
        flag = SettableFlag(available)
    }

    var freeSummaryAvailable: AsyncStream<Bool> { flag.stream }

    /// The twin of assigning to `freeAiCredit.value` (`HomeViewModelTest.kt:159`).
    func set(_ newValue: Bool) {
        flag.set(newValue)
    }
}

/// The twin of `HomeViewModelTest.kt:82-88`'s `MutableStateFlow(PremiumStatus.FREE)` plus the
/// anonymous `PremiumRepository` over it, collapsed to the one boolean ``HomePremiumStatus`` asks
/// for — `isEntitled`, which is what the ViewModel reads on both platforms.
final class FakeHomePremiumStatus: HomePremiumStatus {
    private let flag: SettableFlag

    init(isPremium: Bool) {
        flag = SettableFlag(isPremium)
    }

    var isPremium: AsyncStream<Bool> { flag.stream }

    /// The twin of assigning to `premiumStatus.value` (`HomeViewModelTest.kt:155`).
    func set(_ newValue: Bool) {
        flag.set(newValue)
    }
}

/// A `MutableStateFlow<Bool>`: the current value replayed to every new subscription, then each
/// later one. The two flag fakes above own one each, exactly as the Kotlin file owns two flows.
///
/// The lock discipline is `FakeTodayRepository`'s, for the same reason.
private final class SettableFlag: @unchecked Sendable {
    private let lock = NSLock()
    private var value: Bool
    private var observers: [UUID: @Sendable (Bool) -> Void] = [:]

    init(_ value: Bool) {
        self.value = value
    }

    func set(_ newValue: Bool) {
        let publishers = lock.withLock { () -> [@Sendable (Bool) -> Void] in
            value = newValue
            return Array(observers.values)
        }
        for publish in publishers {
            publish(newValue)
        }
    }

    var stream: AsyncStream<Bool> {
        AsyncStream(bufferingPolicy: .bufferingNewest(1)) { continuation in
            let token = UUID()
            let snapshot = lock.withLock { () -> Bool in
                observers[token] = { snapshot in continuation.yield(snapshot) }
                return value
            }
            continuation.yield(snapshot)
            continuation.onTermination = { [weak self] _ in
                guard let self else { return }
                lock.withLock { _ = observers.removeValue(forKey: token) }
            }
        }
    }
}
