// The dashboard's reminder readiness card, split out of `HomeViewModelTests.swift` for the
// 500-line file limit alone — these are the same suite's concerns, and the fixtures below are that
// file's, narrowed to what a readiness case needs.
//
// **The first three cases are Kotlin's** (`HomeViewModelTest.kt:227-276`), with one substitution
// the iOS ruling forces: Android's soft problem is `BATTERY_OPTIMIZED`, which has no iOS twin, so
// the degraded case denies AlarmKit instead (`ReminderReadiness.swift` — on iOS `notificationsOff`
// is the only hard problem). The remaining five have no Kotlin twin and cover what iOS added: the
// AlarmKit availability flag, the shell's foreground arm, the fact that a repository emission must
// not clear a standing report, and the generation guard that decides which of two overlapping
// reads publishes — a question Kotlin never has to answer, because its environment read blocks.

import Foundation
import SalusCommon
import SalusModel
import SalusReminder
import SalusTesting
import Testing

@testable import FeatureHome

@Suite("HomeViewModel reminder readiness")
@MainActor
struct HomeReadinessTests {
    /// `HomeViewModelTests`' own instant and overview, which nothing here reads for its own sake —
    /// the join has to produce a loaded state before an arrival can be asserted on.
    private static let now = Date(timeIntervalSince1970: 1_760_000_000)

    private let clock = FixedSalusClock(now: HomeReadinessTests.now)
    private let repository = FakeTodayRepository(
        TodayOverview(
            doses: [],
            appointments: [],
            cycle: CycleSnapshot(cycleDay: 12, isPeriodOpen: false),
            vitals: VitalsSnapshot(
                latestWeightKg: 80.0,
                weightTrend: [],
                latestSystolic: nil,
                latestDiastolic: nil,
                latestGlucoseMgdl: nil,
                glucoseUnit: .mgDl
            )
        )
    )
    private let freeAiCredit = FakeHomeAiSummaryAvailability(available: true)
    private let premiumStatus = FakeHomePremiumStatus(isPremium: false)
    private let doseActions = RecordingDoseActions()
    /// `HomeViewModelTest.kt:126` — a healthy device unless a case says otherwise.
    private let environment = FakeReminderEnvironment()
    /// The review prompt's two, which no case here reads: a throwaway defaults suite and a signal
    /// nothing fans out on. They exist so the ViewModel can be built.
    private let preferences = ReviewPromptFixture.makePreferences()
    private let foreground = AppForegroundSignal()

    /// `HomeViewModelTest.kt:94-100`.
    ///
    /// `alarmKitSupported` defaults to true so the degraded case has a soft problem to find at
    /// all: below iOS 26 the environment is never asked about AlarmKit, and a denial there is not
    /// something the user could act on.
    private func viewModel(alarmKitSupported: Bool = true) -> HomeViewModel {
        viewModel(environment: environment, alarmKitSupported: alarmKitSupported)
    }

    /// The same graph around a different environment, for the one case that needs reads it can
    /// hold open rather than answers it can set.
    private func viewModel(
        environment: any ReminderEnvironment,
        alarmKitSupported: Bool = true
    ) -> HomeViewModel {
        HomeViewModel(
            repository: repository,
            aiSummaryAvailability: freeAiCredit,
            premiumStatus: premiumStatus,
            clock: clock,
            doseActions: doseActions,
            environment: environment,
            alarmKitSupported: alarmKitSupported,
            preferences: preferences,
            foreground: foreground
        )
    }

    /// Turbine's `while (state.isLoading) state = awaitItem()` (`HomeViewModelTest.kt:107-108`).
    private func loadedState(_ viewModel: HomeViewModel) async -> HomeUiState {
        await waitUntil("the first loaded state") { !viewModel.state.isLoading }
        return viewModel.state
    }

    /// `HomeViewModelTest.kt:227-239`.
    @Test("a healthy device shows no readiness card")
    func aHealthyDeviceShowsNoReadinessCard() async {
        let viewModel = viewModel()

        _ = await loadedState(viewModel)
        viewModel.onEvent(.appeared)

        // The read is a `Task`, so wait for it to *finish* before concluding it published nothing:
        // `backgroundRefreshAvailable()` is the last of the three questions
        // `readiness(alarmKitSupported:)` asks, so one of those is the whole read.  A bare
        // `settle()` here would also pass on a ViewModel that never asked at all, and — with the
        // review suite now running beside this one — its yield budget is spent on other cases.
        await waitUntil("the arrival's read to finish") { environment.readCount(of: .backgroundRefresh) == 1 }
        // The read having finished is still not the answer having landed: `readiness()` returns on
        // the environment's side of the hop back to `@MainActor`, so the publish is owed a turn
        // that the wait above does not give it. Every nil assertion in this file needs both — the
        // wait, so "nothing published" is not just "nothing published *yet*", and this, so it is
        // not "nothing published *here*". Verified by making `refreshReminderReadiness()` return
        // before its write: the two cases that assert nil stayed green, and all five that wait for
        // a card failed.
        await settle()
        #expect(viewModel.state.reminderReadiness == nil)
    }

    /// `HomeViewModelTest.kt:241-257`, with iOS's own problem list: `notificationsOff` is the hard
    /// one on both platforms, and `backgroundRefreshOff` stands where Android reads
    /// `BATTERY_OPTIMIZED`. Declaration order is worst-first, so the hard problem is `.first` —
    /// which is the one the card's subtitle draws.
    @Test("a broken device shows the card with its hard problem first")
    func aBrokenDeviceShowsTheCardWithItsHardProblemFirst() async {
        environment.set(notifications: false, backgroundRefresh: false)
        let viewModel = viewModel()

        _ = await loadedState(viewModel)
        viewModel.onEvent(.appeared)

        await waitUntil("the readiness report") { viewModel.state.reminderReadiness != nil }
        let report = viewModel.state.reminderReadiness
        #expect(report?.readiness == .broken)
        #expect(report?.problems == [.notificationsOff, .backgroundRefreshOff])
    }

    /// `HomeViewModelTest.kt:259-276`. AlarmKit denied where Android denies the battery exemption:
    /// both are soft, both leave the plain notification standing, and both clear on the next
    /// arrival once the user has fixed them.
    @Test("a degraded device shows the card and a later healthy arrival removes it")
    func aDegradedDeviceShowsTheCardAndALaterHealthyArrivalRemovesIt() async {
        environment.set(alarmKit: false)
        let viewModel = viewModel()

        _ = await loadedState(viewModel)
        viewModel.onEvent(.appeared)

        await waitUntil("the degraded report") { viewModel.state.reminderReadiness != nil }
        #expect(viewModel.state.reminderReadiness?.readiness == .degraded)
        #expect(viewModel.state.reminderReadiness?.problems == [.alarmKitDenied])

        // The user went to Settings and granted it; the arrival that follows is the one that has
        // to take the card away.
        environment.set(alarmKit: true)
        viewModel.onEvent(.appeared)

        await waitUntil("the card to go") { viewModel.state.reminderReadiness == nil }
    }

    /// iOS-only, and the reason ``HomeViewModel`` takes `alarmKitSupported` at all: below iOS 26
    /// there is no AlarmKit to deny, so the same environment must read healthy.
    @Test("AlarmKit is not asked about on a system that has none")
    func alarmKitIsNotAskedAboutOnASystemThatHasNone() async {
        environment.set(alarmKit: false)
        let viewModel = viewModel(alarmKitSupported: false)

        _ = await loadedState(viewModel)
        viewModel.onEvent(.appeared)

        // Waiting for the *last* question rather than spending a yield budget: it is what makes
        // "AlarmKit was never asked" a measurement instead of a race — the read has demonstrably
        // run past the point where it would have asked.
        await waitUntil("the arrival's read to finish") { environment.readCount(of: .backgroundRefresh) == 1 }
        // Same pair as the healthy case above: wait for the read, then hand the publish its turn.
        await settle()
        #expect(viewModel.state.reminderReadiness == nil)
        // The healthy card is only half of it: a run that asked AlarmKit and then discarded a
        // denial it could not act on would look exactly the same from the state. This is the half
        // that says the question was never put.
        #expect(environment.readCount(of: .alarmKit) == 0)
        // And the read did happen — otherwise the line above would pass on a ViewModel that never
        // touched the environment at all.
        #expect(environment.readCount(of: .notifications) == 1)
    }

    /// The shell's `.active` arm is the same arrival as an appearance — the one thing
    /// `HomeRoute`'s `.task` cannot deliver, because SwiftUI does not re-run it for a foreground
    /// return.
    @Test("the shell's foreground arm re-reads the device")
    func theShellsForegroundArmRereadsTheDevice() async {
        let viewModel = viewModel()

        _ = await loadedState(viewModel)
        // The arrival that makes the dashboard visible. `sceneDidBecomeActive()` guards on that
        // visibility (the in-app review prompt's rule: a foreground return counts only for the
        // composed tab), so without this first `.appeared` the arm below would be dropped and the
        // case would pass on a report that never arrived.
        viewModel.onEvent(.appeared)
        await waitUntil("the first arrival's read to finish") { environment.readCount(of: .backgroundRefresh) == 1 }
        // As above — the first arrival's read finishing does not mean its answer has been written.
        await settle()
        #expect(viewModel.state.reminderReadiness == nil, "the device is healthy on the first arrival")

        environment.set(notifications: false)
        viewModel.sceneDidBecomeActive()

        await waitUntil("the readiness report") { viewModel.state.reminderReadiness != nil }
        #expect(viewModel.state.reminderReadiness?.readiness == .broken)
    }

    /// A repository emission must not take the card away: the device is read on arrival only, and
    /// new dose data is not an arrival. This is what carrying the report through
    /// `publish(overview:freeAiSummaryAvailable:isPremium:)` buys, and Kotlin gets it from the
    /// fourth `combine` source.
    @Test("a repository emission keeps the standing readiness report")
    func aRepositoryEmissionKeepsTheStandingReadinessReport() async {
        environment.set(notifications: false)
        let viewModel = viewModel()

        _ = await loadedState(viewModel)
        viewModel.onEvent(.appeared)
        await waitUntil("the readiness report") { viewModel.state.reminderReadiness != nil }

        repository.set(
            TodayOverview(
                doses: [],
                appointments: repository.current.appointments,
                cycle: repository.current.cycle,
                vitals: repository.current.vitals
            )
        )

        await waitUntil("the emptied dose list") { viewModel.state.doses.isEmpty }
        #expect(viewModel.state.reminderReadiness?.readiness == .broken)
    }

    /// Two arrivals can be in flight at once — the Route's `.task` and the shell's foreground arm,
    /// or two foreground returns in a row — and `UNUserNotificationCenter` answers through a
    /// callback whose latency nobody controls, so the second can finish before the first. What
    /// decides the card is then whichever read *landed* last rather than whichever *started* last,
    /// and the answer the user is looking at is one arrival out of date.
    ///
    /// Verified RED by deleting `refreshReminderReadiness()`'s
    /// `guard generation == readinessGeneration`: the card the second read raised disappears again
    /// when the first, healthy read finally resolves.
    @Test("an out-of-order read does not overwrite the latest readiness answer")
    func anOutOfOrderReadDoesNotOverwriteTheLatestReadinessAnswer() async {
        // Read 0 finds a healthy device; read 1, the later arrival, finds notifications denied.
        let environment = GatedReminderEnvironment(notifications: [true, false])
        let viewModel = viewModel(environment: environment)

        _ = await loadedState(viewModel)

        // Both arrivals are started, and both are parked inside the environment. Waiting for each
        // read to begin before starting the next is what makes "read 0" the earlier one.
        viewModel.onEvent(.appeared)
        await waitUntil("the first read to start") { environment.startedReads == 1 }
        viewModel.onEvent(.appeared)
        await waitUntil("the second read to start") { environment.startedReads == 2 }

        // The later arrival answers first, and its report is the one the card draws.
        environment.release(1)
        await waitUntil("the latest report") { viewModel.state.reminderReadiness != nil }
        #expect(viewModel.state.reminderReadiness?.readiness == .broken)

        // The earlier one lands afterwards. It is stale, so its healthy answer publishes nothing.
        environment.release(0)
        await settle()
        #expect(viewModel.state.reminderReadiness?.readiness == .broken)
        #expect(viewModel.state.reminderReadiness?.problems == [.notificationsOff])
    }
}
