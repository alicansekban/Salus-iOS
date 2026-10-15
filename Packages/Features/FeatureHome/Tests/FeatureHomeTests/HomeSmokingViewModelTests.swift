// The smoking card on Home (plan Task 16) — the twin of Android's `HomeSmokingViewModelTest`, case
// for case: the discovery row's dismiss-forever rule, the QUIT and REDUCE mappings, and the "+1"
// with its undo by event id.
//
// Time comes from `FixedSalusClock`; the snackbar is the real controller, read through `current`,
// because what the person sees is the contract (the message, whether an action rides on it).

import Foundation
import SalusCommon
import SalusSettings
import SalusSmoking
import SalusTesting
import SalusUI
import Testing

@testable import FeatureHome

@Suite("HomeViewModel smoking card")
@MainActor
struct HomeSmokingViewModelTests {
    private static let now = Date(timeIntervalSince1970: 1_760_000_000)

    private let clock = FixedSalusClock(now: HomeSmokingViewModelTests.now)
    private let smoking = FakeHomeSmoking()
    private let snackbar = SalusSnackbarController()
    private let preferences = ReviewPromptFixture.makePreferences()

    private func viewModel() -> HomeViewModel {
        HomeViewModel(
            repository: FakeTodayRepository(TodayOverview(
                doses: [],
                appointments: [],
                cycle: CycleSnapshot(cycleDay: nil, isPeriodOpen: false),
                vitals: VitalsSnapshot(
                    latestWeightKg: nil,
                    weightTrend: [],
                    latestSystolic: nil,
                    latestDiastolic: nil,
                    latestGlucoseMgdl: nil,
                    glucoseUnit: .mgDl
                )
            )),
            aiSummaryAvailability: FakeHomeAiSummaryAvailability(available: false),
            premiumStatus: FakeHomePremiumStatus(isPremium: false),
            clock: clock,
            doseActions: RecordingDoseActions(),
            environment: FakeReminderEnvironment(),
            alarmKitSupported: true,
            preferences: preferences,
            foreground: AppForegroundSignal(),
            smoking: smoking,
            snackbar: snackbar
        )
    }

    /// The first state that has both loaded and heard from the smoking source.
    private func settled(_ viewModel: HomeViewModel, card: HomeSmokingCard?) async {
        await waitUntil("the card to read \(String(describing: card))") {
            !viewModel.state.isLoading && viewModel.state.smokingCard == card
        }
    }

    // MARK: - Discovery

    @Test("discovery shows while nothing is set up and the row was not dismissed")
    func discoveryShowsWhileNotSetUp() async {
        let viewModel = viewModel()

        await settled(viewModel, card: .discovery)
    }

    @Test("discovery stays hidden once it was dismissed")
    func discoveryStaysHiddenAfterDismiss() async {
        let viewModel = viewModel()
        await settled(viewModel, card: .discovery)

        viewModel.onEvent(.smokingDiscoveryDismissed)

        await settled(viewModel, card: nil)
        // The flag is the preference itself, so it outlives this ViewModel (and a reset).
        #expect(await preferences.smokingDiscoveryDismissed.firstElement() == true)
    }

    @Test("a dismissal made in an earlier session keeps the row hidden")
    func earlierDismissalKeepsTheRowHidden() async {
        preferences.setSmokingDiscoveryDismissed(true)
        let viewModel = viewModel()

        await settled(viewModel, card: nil)
    }

    @Test("discovery gives way to the quit card once a plan exists")
    func discoveryGivesWayToQuit() async {
        let viewModel = viewModel()
        await settled(viewModel, card: .discovery)

        smoking.set(HomeSmokingFixture.quit())

        await waitUntil("the quit card") {
            if case .quit = viewModel.state.smokingCard {
                true
            } else {
                false
            }
        }
    }

    @Test("a set-up plan wins over a dismissal that was never made")
    func setUpPlanNeverShowsDiscovery() async {
        smoking.set(HomeSmokingFixture.reduce(today: 0, limit: 10))
        let viewModel = viewModel()

        await settled(viewModel, card: .reduce(today: 0, limit: 10, overflow: 0))
    }

    // MARK: - QUIT and REDUCE

    @Test("quit card carries whole days, savings, currency and the next stage")
    func quitCardMapsTheSnapshot() async {
        smoking.set(HomeSmokingFixture.quit())
        let viewModel = viewModel()

        await settled(
            viewModel,
            card: .quit(HomeSmokingQuit(
                days: 42,
                savedMinor: 315_000,
                currency: "TRY",
                nextStagePermille: 700,
                nextStageRemainingMs: 3 * HomeSmokingFixture.day
            ))
        )
    }

    @Test("quit card has no next stage once every stage is done")
    func quitCardWithoutNextStage() async {
        smoking.set(HomeSmokingFixture.quit(elapsedMs: 0, savedMinor: 0, nextStage: nil))
        let viewModel = viewModel()

        await settled(
            viewModel,
            card: .quit(HomeSmokingQuit(
                days: 0,
                savedMinor: 0,
                currency: "TRY",
                nextStagePermille: nil,
                nextStageRemainingMs: nil
            ))
        )
    }

    @Test("reduce card under the limit has no overflow")
    func reduceUnderLimit() async {
        smoking.set(HomeSmokingFixture.reduce(today: 6, limit: 10))
        let viewModel = viewModel()

        await settled(viewModel, card: .reduce(today: 6, limit: 10, overflow: 0))
    }

    @Test("reduce card over the limit reports the excess")
    func reduceOverLimit() async {
        smoking.set(HomeSmokingFixture.reduce(today: 12, limit: 10))
        let viewModel = viewModel()

        await settled(viewModel, card: .reduce(today: 12, limit: 10, overflow: 2))
    }

    // MARK: - The "+1"

    @Test("plus one writes one smoked unit now and offers an undo")
    func plusOneWritesAndOffersUndo() async {
        smoking.set(HomeSmokingFixture.reduce(today: 6, limit: 10))
        let viewModel = viewModel()
        await settled(viewModel, card: .reduce(today: 6, limit: 10, overflow: 0))

        viewModel.onEvent(.smokingPlusOne)
        await waitUntil("the snackbar") { snackbar.current != nil }

        #expect(smoking.logged == [clock.nowEpochMilliseconds()])
        #expect(snackbar.current?.message == HomeStrings.smokingAdded)
        #expect(snackbar.current?.actionLabel == SalusUIStrings.undo)
    }

    @Test("undo deletes exactly the event it wrote, even after midnight")
    func undoDeletesByIdAcrossMidnight() async {
        smoking.set(HomeSmokingFixture.reduce(today: 6, limit: 10))
        let viewModel = viewModel()
        await settled(viewModel, card: .reduce(today: 6, limit: 10, overflow: 0))

        viewModel.onEvent(.smokingPlusOne)
        await waitUntil("the first snackbar") { snackbar.current != nil }
        snackbar.dismiss()
        viewModel.onEvent(.smokingPlusOne)
        await waitUntil("the second snackbar") { snackbar.current != nil && smoking.logged.count == 2 }

        // The first tap's snackbar is long gone; the person undoes the SECOND one after the day
        // rolled over. A "delete today's latest" would take the wrong row or none at all.
        clock.advanceTo(Self.now.addingTimeInterval(24 * 60 * 60))
        snackbar.performAction()
        await waitUntil("the delete") { !smoking.deleted.isEmpty }

        #expect(smoking.deleted == ["evt-2"])
    }

    @Test("a double tap on plus one writes once")
    func doubleTapWritesOnce() async {
        smoking.set(HomeSmokingFixture.reduce(today: 6, limit: 10))
        let viewModel = viewModel()
        await settled(viewModel, card: .reduce(today: 6, limit: 10, overflow: 0))
        smoking.holdLogs()
        var completions = smoking.logCompletions.makeAsyncIterator()

        viewModel.onEvent(.smokingPlusOne)
        viewModel.onEvent(.smokingPlusOne)
        // The first write is at the gate; whatever a missing guard would have started has had its
        // turns too before the gate opens.
        await waitUntil("the first write to reach the store") { smoking.logCallsEntered >= 1 }
        await settle()
        smoking.releaseLogs()
        await completions.next()
        await waitUntil("the snackbar") { snackbar.current != nil }
        await settle()

        #expect(smoking.logged.count == 1)
        #expect(smoking.logCallsEntered == 1)
    }

    @Test("a tap after the first write finished writes again")
    func secondTapAfterCompletionWritesAgain() async {
        smoking.set(HomeSmokingFixture.reduce(today: 6, limit: 10))
        let viewModel = viewModel()
        await settled(viewModel, card: .reduce(today: 6, limit: 10, overflow: 0))
        var completions = smoking.logCompletions.makeAsyncIterator()

        viewModel.onEvent(.smokingPlusOne)
        await completions.next()
        // The snackbar is shown in the same main-actor step that clears the in-flight flag, so once
        // it is up a second tap is no longer dropped.
        await waitUntil("the first write to finish") { snackbar.current != nil }
        viewModel.onEvent(.smokingPlusOne)
        // Bounded by the helper's deadline: if the tap were wrongly dropped nothing would ever
        // complete, and an unbounded `next()` would hang instead of failing.
        await waitUntil("the second write") { smoking.logged.count == 2 }
    }

    @Test("plus one is ignored unless the card is the reduce card")
    func plusOneNeedsTheReduceCard() async {
        smoking.set(HomeSmokingFixture.quit())
        let viewModel = viewModel()
        await waitUntil("the quit card") {
            if case .quit = viewModel.state.smokingCard {
                true
            } else {
                false
            }
        }

        viewModel.onEvent(.smokingPlusOne)
        await settle()

        #expect(smoking.logged.isEmpty)
        #expect(snackbar.current == nil)
    }

    @Test("a refused write becomes a plain snackbar and leaves the card alone")
    func refusedWriteShowsAPlainError() async {
        smoking.set(HomeSmokingFixture.reduce(today: 6, limit: 10))
        let viewModel = viewModel()
        await settled(viewModel, card: .reduce(today: 6, limit: 10, overflow: 0))
        smoking.refuseNextLog()

        viewModel.onEvent(.smokingPlusOne)
        await waitUntil("the error") { snackbar.current != nil }

        #expect(snackbar.current?.message == HomeStrings.smokingError)
        #expect(snackbar.current?.actionLabel == nil)
        #expect(viewModel.state.smokingCard == .reduce(today: 6, limit: 10, overflow: 0))
    }

    @Test("a refused undo is reported the same way")
    func refusedUndoShowsAPlainError() async {
        smoking.set(HomeSmokingFixture.reduce(today: 6, limit: 10))
        let viewModel = viewModel()
        await settled(viewModel, card: .reduce(today: 6, limit: 10, overflow: 0))
        viewModel.onEvent(.smokingPlusOne)
        await waitUntil("the snackbar") { snackbar.current != nil }
        smoking.refuseNextDelete()

        snackbar.performAction()
        await waitUntil("the error") { snackbar.current?.message == HomeStrings.smokingError }
    }
}

extension AsyncStream {
    /// The first element, for a flag stream that always has one ready.
    fileprivate func firstElement() async -> Element? {
        var iterator = makeAsyncIterator()
        return await iterator.next()
    }
}
