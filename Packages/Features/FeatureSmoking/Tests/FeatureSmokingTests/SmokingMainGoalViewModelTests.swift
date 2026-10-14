// Ported from `feature/smoking/src/test/kotlin/com/alicansekban/salus/feature/smoking/ui/main/
// SmokingMainGoalViewModelTest.kt`: the savings-goal card and the insights teaser of the main
// screen — who sees what, what a tap does for a free and for a premium account, and the goal's
// writes. They run the real use cases against the in-memory store, like the rest of the screen's
// tests.
//
// Editing a goal still being saved for keeps its progress (contract §8.17, parity D-M17-ae), which
// supersedes plan ruling D4's restart: the edit cases pin the same row, the same `createdAtMs`.

import SalusPremium
import SalusSmoking
import SalusTesting
import Testing

@testable import FeatureSmoking

@MainActor
@Suite("SmokingMainViewModel savings goal", .timeLimit(.minutes(1)))
struct SmokingMainGoalViewModelTests {
    // MARK: The goal card by entitlement

    @Test("a free account is shown the locked card, and a tap on it opens the goal paywall")
    func freeTapOpensThePaywall() async {
        let harness = GoalHarness(goal: nil, status: .free)
        let vm = await harness.subscribedViewModel(status: .free)
        #expect(vm.state.goalCard() == .locked)

        vm.onEvent(.goalTapped)

        #expect(harness.paywall.request == PaywallRequest(source: .smokingGoal))
        #expect(vm.state.sheet == nil, "a locked card opens no sheet")
    }

    @Test("a premium tap with no goal opens an empty goal sheet and no paywall")
    func premiumTapWithNoGoalOpensAnEmptySheet() async {
        let harness = GoalHarness(goal: nil)
        let vm = await harness.subscribedViewModel()

        vm.onEvent(.goalTapped)

        #expect(vm.state.sheet == .goal(title: "", targetMinor: nil, editingGoalId: nil))
        #expect(harness.paywall.request == nil)
    }

    @Test("a premium tap on a goal in progress opens the sheet with that goal")
    func premiumTapOnAGoalInProgressOpensTheSheetWithIt() async {
        let harness = GoalHarness(goal: GoalHarness.goal(target: 800_000))
        let vm = await harness.subscribedViewModel()
        guard case .inProgress = vm.state.goalCard() else {
            Issue.record("expected an in-progress card")
            return
        }

        vm.onEvent(.goalTapped)

        #expect(vm.state.sheet == .goal(title: "Yeni bisiklet", targetMinor: 800_000, editingGoalId: "goal-1"))
    }

    @Test("a tap on a reached goal opens an empty sheet for the next one")
    func tapOnAReachedGoalOpensAnEmptySheet() async {
        let harness = GoalHarness(goal: GoalHarness.goal(target: 50000, achievedAtMs: GoalHarness.noon - dayMs))
        let vm = await harness.subscribedViewModel()
        guard case .reached = vm.state.goalCard() else {
            Issue.record("expected a reached card")
            return
        }

        vm.onEvent(.goalTapped)

        #expect(vm.state.sheet == .goal(title: "", targetMinor: nil, editingGoalId: nil))
    }

    @Test("the goal card exists in REDUCE too")
    func goalCardExistsInReduce() async {
        let harness = GoalHarness(goal: GoalHarness.goal(target: 800_000), mode: .reduce)
        let vm = await harness.subscribedViewModel()

        guard case .inProgress = vm.state.goalCard() else {
            Issue.record("expected an in-progress card")
            return
        }
    }

    // MARK: Saving a goal

    @Test("saving writes the goal through the use case and closes the sheet")
    func savingWritesTheGoalAndClosesTheSheet() async {
        let harness = GoalHarness(goal: nil)
        let vm = await harness.subscribedViewModel()
        vm.onEvent(.goalTapped)

        vm.onEvent(.goalSaved(title: "  Yeni bisiklet ", targetMinor: 800_000))
        await waitUntil("the sheet closes") { vm.state.sheet == nil }

        let saved = harness.store.input.goal
        #expect(saved?.title == "Yeni bisiklet")
        #expect(saved?.targetMinor == 800_000)
        #expect(saved?.createdAtMs == harness.nowMs, "created now, so no earlier money counts toward it (D4)")
        #expect(!vm.state.writing)
        await waitUntil("the new goal is the card's goal") {
            if case .inProgress = vm.state.goalCard() {
                true
            } else {
                false
            }
        }
    }

    @Test("saving an edit of the goal in progress keeps the goal and its progress")
    func editKeepsTheGoalAndItsProgress() async throws {
        let harness = GoalHarness(goal: GoalHarness.goal(target: 800_000))
        let vm = await harness.subscribedViewModel()
        guard case let .inProgress(before) = vm.state.goalCard() else {
            Issue.record("expected an in-progress card")
            return
        }
        vm.onEvent(.goalTapped)

        vm.onEvent(.goalSaved(title: "  Tatil ", targetMinor: 900_000))
        await waitUntil("the sheet closes") { vm.state.sheet == nil }

        let saved = try #require(harness.store.input.goal)
        #expect(saved.id == "goal-1", "the same row, not a new goal")
        #expect(
            saved.createdAtMs == harness.nowMs - 10 * dayMs,
            "created then, so the progress is not restarted (D4 superseded by 8.17)"
        )
        #expect(saved.title == "Tatil")
        #expect(saved.targetMinor == 900_000)
        #expect(harness.ids.newId() == "id-1", "an edit takes no new id")
        #expect(!vm.state.writing)
        await waitUntil("the card follows the write") {
            if case let .inProgress(goal) = vm.state.goalCard(), goal.targetMinor == 900_000 {
                true
            } else {
                false
            }
        }
        guard case let .inProgress(after) = vm.state.goalCard() else {
            Issue.record("expected an in-progress card")
            return
        }
        #expect(after.savedMinor == before.savedMinor)
    }

    @Test("lowering the target of the goal in progress below what is saved reaches it and stamps it")
    func loweringTheTargetReachesAndStampsTheGoal() async {
        let harness = GoalHarness(goal: GoalHarness.goal(target: 800_000))
        let vm = await harness.subscribedViewModel()
        vm.onEvent(.goalTapped)

        vm.onEvent(.goalSaved(title: "Yeni bisiklet", targetMinor: 50000))
        await waitUntil("the goal is stamped") { harness.store.input.goal?.achievedAtMs != nil }

        #expect(harness.store.input.goal?.id == "goal-1")
        #expect(harness.store.input.goal?.achievedAtMs == harness.nowMs)
        await waitUntil("the card reads reached") {
            if case .reached = vm.state.goalCard() {
                true
            } else {
                false
            }
        }
    }

    @Test("a new goal after a reached one is created fresh and counts from now")
    func newGoalAfterAReachedOneIsCreatedFresh() async throws {
        let harness = GoalHarness(goal: GoalHarness.goal(target: 50000, achievedAtMs: GoalHarness.noon - dayMs))
        let vm = await harness.subscribedViewModel()
        vm.onEvent(.goalTapped)

        vm.onEvent(.goalSaved(title: "Tatil", targetMinor: 900_000))
        await waitUntil("the sheet closes") { vm.state.sheet == nil }

        let saved = try #require(harness.store.input.goal)
        #expect(saved.id == "id-1")
        #expect(saved.createdAtMs == harness.nowMs)
    }

    @Test("a refused edit leaves the sheet open and the goal untouched, and says so")
    func refusedEditLeavesTheSheetOpen() async {
        let harness = GoalHarness(goal: GoalHarness.goal(target: 800_000))
        let vm = await harness.subscribedViewModel()
        vm.onEvent(.goalTapped)
        harness.store.failure = FakeStorageFault()

        vm.onEvent(.goalSaved(title: "Tatil", targetMinor: 900_000))
        await waitUntil("the error") { !vm.pendingEffects.isEmpty }

        #expect(vm.consumeEffects() == [.showError(.generic)])
        #expect(harness.store.input.goal == GoalHarness.goal(target: 800_000))
        #expect(vm.state.sheet == .goal(title: "Yeni bisiklet", targetMinor: 800_000, editingGoalId: "goal-1"))
        #expect(!vm.state.writing, "the buttons come back")
    }

    @Test("a target of zero on an edit is refused by the use case and shown as an error")
    func zeroTargetOnAnEditIsRefused() async {
        let harness = GoalHarness(goal: GoalHarness.goal(target: 800_000))
        let vm = await harness.subscribedViewModel()
        vm.onEvent(.goalTapped)

        vm.onEvent(.goalSaved(title: "Tatil", targetMinor: 0))
        await waitUntil("the error") { !vm.pendingEffects.isEmpty }

        #expect(vm.consumeEffects() == [.showError(.generic)])
        #expect(harness.store.input.goal == GoalHarness.goal(target: 800_000))
    }

    @Test("a refused save leaves the sheet open and the goal untouched, and says so")
    func refusedSaveLeavesTheSheetOpen() async {
        let harness = GoalHarness(goal: nil)
        let vm = await harness.subscribedViewModel()
        vm.onEvent(.goalTapped)
        harness.store.failure = FakeStorageFault()

        vm.onEvent(.goalSaved(title: "Yeni bisiklet", targetMinor: 800_000))
        await waitUntil("the error") { !vm.pendingEffects.isEmpty }

        #expect(vm.consumeEffects() == [.showError(.generic)])
        #expect(harness.store.input.goal == nil)
        #expect(vm.state.sheet == .goal(title: "", targetMinor: nil, editingGoalId: nil))
        #expect(!vm.state.writing, "the buttons come back")
    }

    @Test("a target of zero is refused by the use case and shown as an error")
    func zeroTargetIsRefused() async {
        let harness = GoalHarness(goal: nil)
        let vm = await harness.subscribedViewModel()
        vm.onEvent(.goalTapped)

        vm.onEvent(.goalSaved(title: "Yeni bisiklet", targetMinor: 0))
        await waitUntil("the error") { !vm.pendingEffects.isEmpty }

        #expect(vm.consumeEffects() == [.showError(.generic)])
        #expect(harness.store.input.goal == nil)
    }

    @Test("a second tap on save while the first is in flight writes once")
    func secondSaveWritesOnce() async {
        let harness = GoalHarness(goal: nil)
        let vm = await harness.subscribedViewModel()
        vm.onEvent(.goalTapped)
        let gate = WriteGate()
        harness.store.gate = gate

        vm.onEvent(.goalSaved(title: "Yeni bisiklet", targetMinor: 800_000))
        vm.onEvent(.goalSaved(title: "Yeni bisiklet", targetMinor: 800_000))
        await waitUntil("the first write is started") { harness.store.calls == 1 }
        gate.open()
        await waitUntil("the write ends") { !vm.state.writing }
        await harness.settle()

        #expect(harness.store.calls == 1)
        #expect(harness.store.commits == 1)
    }

    @Test("dismissing the sheet writes nothing, and cannot happen mid-write")
    func dismissingWritesNothingAndNotMidWrite() async {
        let harness = GoalHarness(goal: nil)
        let vm = await harness.subscribedViewModel()
        vm.onEvent(.goalTapped)

        vm.onEvent(.goalDismissed)

        #expect(vm.state.sheet == nil)
        #expect(harness.store.calls == 0)

        vm.onEvent(.goalTapped)
        let gate = WriteGate()
        harness.store.gate = gate
        vm.onEvent(.goalSaved(title: "Yeni bisiklet", targetMinor: 800_000))
        await waitUntil("the write is started") { harness.store.calls == 1 }
        vm.onEvent(.goalDismissed)
        guard case .goal = vm.state.sheet else {
            Issue.record("the write is on its way: the sheet stays")
            return
        }
        gate.open()
        await waitUntil("the write ends") { !vm.state.writing }
    }

    @Test("a save does nothing when no goal sheet is open")
    func saveWithNoSheetDoesNothing() async {
        let harness = GoalHarness(goal: nil)
        let vm = await harness.subscribedViewModel()

        vm.onEvent(.goalSaved(title: "Yeni bisiklet", targetMinor: 800_000))
        await harness.settle()

        #expect(harness.store.calls == 0)
    }
}

@MainActor
@Suite("SmokingMainViewModel savings goal, lapse and teaser", .timeLimit(.minutes(1)))
struct SmokingMainGoalLapseViewModelTests {
    // MARK: A premium lapse

    @Test("a lapse re-locks the card and keeps the goal row")
    func lapseReLocksTheCardAndKeepsTheGoal() async {
        let harness = GoalHarness(goal: GoalHarness.goal(target: 800_000))
        let vm = await harness.subscribedViewModel()
        guard case .inProgress = vm.state.goalCard() else {
            Issue.record("expected an in-progress card")
            return
        }

        harness.premium.setValue(.free)
        await waitUntil("the lock") { vm.state.goalCard() == .locked }

        #expect(harness.store.input.goal == GoalHarness.goal(target: 800_000), "the goal is not deleted")
        #expect(harness.store.calls == 0, "and nothing is written")
        vm.onEvent(.goalTapped)
        #expect(harness.paywall.request == PaywallRequest(source: .smokingGoal))

        harness.premium.setValue(.premium)
        await waitUntil("the same goal comes back") {
            if case .inProgress = vm.state.goalCard() {
                true
            } else {
                false
            }
        }
    }

    @Test("a lapse closes an open goal sheet")
    func lapseClosesAnOpenGoalSheet() async {
        let harness = GoalHarness(goal: nil)
        let vm = await harness.subscribedViewModel()
        vm.onEvent(.goalTapped)

        harness.premium.setValue(.free)
        await waitUntil("the sheet closes") { vm.state.sheet == nil }
    }

    // MARK: Reached marks once

    @Test("a goal that has reached its target is stamped as achieved")
    func reachedGoalIsStamped() async {
        let harness = GoalHarness(goal: GoalHarness.goal(target: 50000))
        let vm = harness.viewModel()

        await waitUntil("the stamp") { harness.store.input.goal?.achievedAtMs != nil }
        await harness.settle()

        #expect(harness.store.input.goal?.achievedAtMs == harness.nowMs)
        #expect(harness.store.commits == 1)
        await waitUntil("the card reads reached") {
            if case .reached = vm.state.goalCard() {
                true
            } else {
                false
            }
        }
    }

    @Test("a goal in progress is not stamped")
    func goalInProgressIsNotStamped() async {
        let harness = GoalHarness(goal: GoalHarness.goal(target: 800_000))
        _ = await harness.subscribedViewModel()
        await harness.settle()

        #expect(harness.store.input.goal?.achievedAtMs == nil)
        #expect(harness.store.calls == 0)
    }

    @Test("a goal already stamped is not stamped again")
    func stampedGoalIsNotStampedAgain() async {
        let harness = GoalHarness(goal: GoalHarness.goal(target: 50000, achievedAtMs: GoalHarness.noon - dayMs))
        _ = await harness.subscribedViewModel()
        await harness.settle()

        #expect(harness.store.calls == 0)
        #expect(harness.store.input.goal?.achievedAtMs == harness.nowMs - dayMs)
    }

    @Test("re-emissions while the stamp is in flight do not start a second one")
    func reEmissionsDoNotStartASecondStamp() async {
        let harness = GoalHarness(goal: GoalHarness.goal(target: 50000))
        let gate = WriteGate()
        harness.store.gate = gate
        let vm = harness.viewModel()
        await waitUntil("the first stamp is waiting on the store") { harness.store.calls == 1 }

        // Each flip re-emits the premium flag, and the state, while the write has not landed.
        harness.premium.setValue(.free)
        await waitUntil("the lock") { !vm.state.isPremium }
        harness.premium.setValue(.premium)
        await waitUntil("the unlock") { vm.state.isPremium }
        await harness.settle()
        #expect(harness.store.calls == 1, "still one")

        gate.open()
        await waitUntil("the stamp lands") { harness.store.input.goal?.achievedAtMs != nil }
        harness.premium.setValue(.free)
        await waitUntil("the lock") { !vm.state.isPremium }
        harness.premium.setValue(.premium)
        await waitUntil("the unlock") { vm.state.isPremium }
        await harness.settle()

        #expect(harness.store.calls == 1, "a stamped goal needs no more")
        #expect(harness.store.commits == 1)
    }

    @Test("a failed stamp is tried again on the next emission, and silently")
    func failedStampIsRetriedSilently() async {
        let harness = GoalHarness(goal: GoalHarness.goal(target: 50000))
        harness.store.failure = FakeStorageFault()
        let vm = harness.viewModel()
        await waitUntil("the failed stamp") { harness.store.calls == 1 }
        await harness.settle()
        #expect(harness.store.input.goal?.achievedAtMs == nil)
        #expect(vm.pendingEffects.isEmpty, "no error: the person did nothing")
        #expect(harness.snackbar.current == nil, "no snackbar either")

        harness.store.failure = nil
        harness.premium.setValue(.free)
        await waitUntil("the lock") { !vm.state.isPremium }
        harness.premium.setValue(.premium)

        await waitUntil("the retry lands") { harness.store.input.goal?.achievedAtMs != nil }
        #expect(harness.store.input.goal?.achievedAtMs == harness.nowMs)
    }

    @Test("a free account's reached goal is left alone until it is premium again")
    func freeAccountsReachedGoalIsLeftAlone() async {
        let harness = GoalHarness(goal: GoalHarness.goal(target: 50000), status: .free)
        let vm = await harness.subscribedViewModel(status: .free)
        await harness.settle()

        #expect(harness.store.calls == 0)
        #expect(harness.store.input.goal?.achievedAtMs == nil)

        harness.premium.setValue(.premium)
        await waitUntil("the stamp") { harness.store.input.goal?.achievedAtMs != nil }

        #expect(harness.store.input.goal?.achievedAtMs == harness.nowMs)
        #expect(vm.state.isPremium)
    }

    // MARK: Insights teaser

    @Test("a free tap on the teaser opens the insights paywall and not Trends")
    func freeTapOnTheTeaserOpensThePaywall() async {
        let harness = GoalHarness(goal: nil, status: .free)
        let vm = await harness.subscribedViewModel(status: .free)

        vm.onEvent(.insightsTapped)
        await harness.settle()

        #expect(vm.pendingEffects.isEmpty)
        #expect(harness.paywall.request == PaywallRequest(source: .smokingInsights))
    }

    @Test("a premium tap on the teaser opens Trends and no paywall")
    func premiumTapOnTheTeaserOpensTrends() async {
        let harness = GoalHarness(goal: nil)
        let vm = await harness.subscribedViewModel()

        vm.onEvent(.insightsTapped)

        #expect(vm.consumeEffects() == [.openTrends])
        #expect(harness.paywall.request == nil)
    }
}
