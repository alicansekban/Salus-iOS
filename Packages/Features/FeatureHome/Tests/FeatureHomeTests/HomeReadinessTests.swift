// The dashboard's reminder readiness card, split out of `HomeViewModelTests.swift` for the
// 500-line file limit alone — these are the same suite's concerns, and the fixtures below are that
// file's, narrowed to what a readiness case needs.
//
// **The first three cases are Kotlin's** (`HomeViewModelTest.kt:227-276`), with one substitution
// the iOS ruling forces: Android's soft problem is `BATTERY_OPTIMIZED`, which has no iOS twin, so
// the degraded case denies AlarmKit instead (`ReminderReadiness.swift` — on iOS `notificationsOff`
// is the only hard problem). The remaining four have no Kotlin twin and cover what iOS added: the
// AlarmKit availability flag, the shell's foreground arm, and the fact that a repository emission
// must not clear a standing report.

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

        // The read is a `Task`, so give it every chance to publish something before concluding it
        // published nothing — Kotlin's `expectNoEvents()` has the same job.
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

        await settle()
        #expect(viewModel.state.reminderReadiness == nil)
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

    /// Lets every already-queued `Task` run, so "nothing was published" is a measurement rather
    /// than a race. The twin of Turbine's `expectNoEvents()`, which is what the two cases above
    /// would say in Kotlin.
    private func settle() async {
        for _ in 0 ..< 100 {
            await Task.yield()
        }
    }
}
