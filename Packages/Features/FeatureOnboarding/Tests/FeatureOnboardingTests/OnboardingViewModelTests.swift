// Ported 1:1 from
// `feature/onboarding/src/test/kotlin/com/alicansekban/salus/feature/onboarding/ui/
// OnboardingViewModelTest.kt`.
//
// All thirteen Kotlin cases port by name (backtick → camelCase). Five substitutions, four of them
// the house pattern the M7/M8 ViewModel tests already set:
//
//   1. `MainDispatcherRule` + `runTest`'s virtual scheduler → the cooperative pool. Each
//      `advanceUntilIdle()` becomes a `waitUntil` that yields the main actor until the named
//      condition holds (`FeatureSettings/Tests/.../WaitUntil.swift`).
//   2. `repository.profiles.value!!` → `repository.profile`, the lock-guarded read the fake exposes.
//   3. `Triple(72.4, now.toEpochMilliseconds(), "Europe/Istanbul")` → a named ``RecordedWeight``.
//   4. Ruling 7's ordering — profile write, then weight, then the completion flag — is asserted
//      through the shared ``FinishOrderLog``. The Kotlin test asserts the three writes happened but
//      not their order; the ruling makes the order binding, so it is pinned here.
//   5. `vm.effects.test { … expectNoEvents() }` (Turbine over a `Channel`) → the buffered
//      `pendingEffects` queue the M8 `MoreViewModel` established for an `@Observable`. The Kotlin
//      comment on the negative cases is the rule here too, and it is why every one of them waits
//      for the completion flag before reading the queue: `finish()` runs in a detached task, so
//      "no effect" asserted on a state that has not had the chance to change is vacuous.

import Foundation
import SalusCommon
import SalusModel
import SalusTesting
import Testing

@testable import FeatureOnboarding

@Suite("OnboardingViewModel")
@MainActor
struct OnboardingViewModelTests {
    /// `OnboardingViewModelTest.kt:80` — the instant the fixed clock stands at.
    private static let now = Date(epochMilliseconds: 1_750_000_000_000)

    /// The four fakes the Kotlin test holds as fields (`OnboardingViewModelTest.kt:77-81`), rebuilt
    /// per case so no state leaks across them. `FixedSalusClock`'s default zone is already
    /// `Europe/Istanbul`, the zone `OnboardingViewModelTest.kt:81` names.
    private struct Fixture {
        let vm: OnboardingViewModel
        let repository: FakeProfileRepository
        let vitals: FakeVitalsQuickEntry
        let preferences: FakeOnboardingPreferences
        let orderLog: FinishOrderLog
    }

    /// `OnboardingViewModelTest.kt:83-89`. `failing` has no Kotlin twin — see
    /// ``aFailingWriteAbortsBeforeTheCompletionFlagAndLeavesTheStepRetryable(failing:)``.
    private func makeFixture(
        includeNotificationStep: Bool = true,
        failing: FailingWrite? = nil
    ) -> Fixture {
        let orderLog = FinishOrderLog()
        let repository = FakeProfileRepository(
            orderLog: orderLog,
            saveFailure: failing == .profile ? FakeWriteFailure() : nil
        )
        let vitals = FakeVitalsQuickEntry(
            orderLog: orderLog,
            failure: failing == .weight ? FakeWriteFailure() : nil
        )
        let preferences = FakeOnboardingPreferences(orderLog: orderLog)
        let vm = OnboardingViewModel(
            profileRepository: repository,
            vitalsQuickEntry: vitals,
            preferences: preferences,
            clock: FixedSalusClock(now: Self.now),
            includeNotificationStep: includeNotificationStep
        )
        return Fixture(
            vm: vm,
            repository: repository,
            vitals: vitals,
            preferences: preferences,
            orderLog: orderLog
        )
    }

    /// `OnboardingViewModelTest.kt:91-101`.
    @Test("the flow is three pages whether or not notifications can be asked for")
    func theFlowIsThreePagesWhetherOrNotNotificationsCanBeAskedFor() {
        #expect(makeFixture().vm.state.steps == OnboardingStep.allCases)
        #expect(
            makeFixture(includeNotificationStep: false).vm.state.steps == OnboardingStep.allCases,
            "the page stays; only its switch row goes"
        )
        #expect(makeFixture().vm.state.remindersAvailable)
        #expect(makeFixture(includeNotificationStep: false).vm.state.remindersAvailable == false)
    }

    /// `OnboardingViewModelTest.kt:103-111`.
    @Test("reminders start on and follow the switch")
    func remindersStartOnAndFollowTheSwitch() {
        let vm = makeFixture().vm
        #expect(vm.state.remindersEnabled)

        vm.onEvent(.remindersToggled(false))

        #expect(vm.state.remindersEnabled == false)
    }

    /// `OnboardingViewModelTest.kt:113-128`.
    @Test("continuing from the personal page waits for a sex")
    func continuingFromThePersonalPageWaitsForASex() {
        let vm = makeFixture().vm
        vm.onEvent(.nextClicked)
        #expect(vm.state.step == .personalDetails)
        #expect(vm.state.canContinue == false)

        vm.onEvent(.nextClicked)
        #expect(vm.state.step == .personalDetails, "without a sex the flow stays put")

        vm.onEvent(.sexSelected(.female))
        #expect(vm.state.canContinue)
        vm.onEvent(.nextClicked)

        #expect(vm.state.step == .healthAndPermissions)
    }

    /// `OnboardingViewModelTest.kt:130-141`.
    @Test("skipping the personal page waits for a sex too")
    func skippingThePersonalPageWaitsForASexToo() {
        let vm = makeFixture().vm
        vm.onEvent(.nextClicked)
        vm.onEvent(.nameChanged("Ada"))

        #expect(vm.state.canSkip == false)
        vm.onEvent(.skipClicked)

        #expect(vm.state.step == .personalDetails)
        #expect(vm.state.name == "Ada", "nothing is thrown away while the page is still blocked")
    }

    /// `OnboardingViewModelTest.kt:143-163`.
    @Test("skipping the personal page clears its optional answers and keeps the sex")
    func skippingThePersonalPageClearsItsOptionalAnswersAndKeepsTheSex() {
        let vm = makeFixture().vm
        vm.onEvent(.nextClicked)
        vm.onEvent(.nameChanged("Ada"))
        vm.onEvent(.sexSelected(.female))
        vm.onEvent(.birthDateSelected(LocalDate(year: 1990, month: 6, day: 15).epochDay))
        vm.onEvent(.heightChanged("170"))
        vm.onEvent(.weightChanged("72,4"))

        #expect(vm.state.canSkip)
        vm.onEvent(.skipClicked)

        let state = vm.state
        #expect(state.step == .healthAndPermissions)
        #expect(state.name.isEmpty)
        #expect(state.birthDateEpochDay == nil)
        #expect(state.heightText.isEmpty)
        #expect(state.weightText.isEmpty)
        #expect(state.sex == .female, "the one answer the app cannot work without survives")
    }

    /// `OnboardingViewModelTest.kt:165-184`.
    @Test("skipping the last page clears the notes, asks for nothing and finishes")
    func skippingTheLastPageClearsTheNotesAsksForNothingAndFinishes() async {
        let fixture = makeFixture()
        let vm = fixture.vm
        vm.goToLastPage()
        vm.onEvent(.healthNotesChanged("Pollen allergy"))

        vm.onEvent(.skipClicked)
        // The write runs in a detached task like any other: without letting it finish, "no effect"
        // would hold even for an effect that was in fact queued.
        await waitUntil("the completion flag to be written") { fixture.preferences.completed }

        #expect(vm.pendingEffects.isEmpty)
        #expect(vm.state.healthNotes.isEmpty)
        #expect(fixture.repository.profile?.healthNotes == nil)
        #expect(fixture.preferences.completed)
    }

    /// `OnboardingViewModelTest.kt:186-200`.
    @Test("finishing asks for the notification permission while the switch is on")
    func finishingAsksForTheNotificationPermissionWhileTheSwitchIsOn() async {
        let fixture = makeFixture()
        let vm = fixture.vm
        vm.goToLastPage()

        vm.onEvent(.nextClicked)

        #expect(vm.pendingEffects == [.requestNotificationPermission])
        await waitUntil("the completion flag to be written") { fixture.preferences.completed }

        #expect(fixture.preferences.completed, "the answer never gates the setup")
    }

    /// `OnboardingViewModelTest.kt:202-217`.
    @Test("finishing asks for nothing once the switch is off")
    func finishingAsksForNothingOnceTheSwitchIsOff() async {
        let fixture = makeFixture()
        let vm = fixture.vm
        vm.goToLastPage()
        vm.onEvent(.remindersToggled(false))

        vm.onEvent(.nextClicked)
        await waitUntil("the completion flag to be written") { fixture.preferences.completed }

        #expect(vm.pendingEffects.isEmpty)
        #expect(fixture.preferences.completed)
    }

    /// `OnboardingViewModelTest.kt:219-234`, whose name is Android's: below API 33 the permission
    /// does not exist, so the row is not offered. iOS has no API-level gate —
    /// `UNUserNotificationCenter` exists on every supported version — so the twin of "below API 33"
    /// here is `remindersAvailable == false`, which is what `includeNotificationStep: false`
    /// produces. The name is kept so the two suites still read as one table.
    @Test("finishing asks for nothing below API 33")
    func finishingAsksForNothingBelowApi33() async {
        let fixture = makeFixture(includeNotificationStep: false)
        let vm = fixture.vm
        vm.goToLastPage()
        #expect(vm.state.remindersEnabled, "the switch is hidden, not flipped")

        vm.onEvent(.nextClicked)
        await waitUntil("the completion flag to be written") { fixture.preferences.completed }

        #expect(vm.pendingEffects.isEmpty)
        #expect(fixture.preferences.completed)
    }

    /// `OnboardingViewModelTest.kt:236-248`.
    @Test("back steps between the pages and does nothing on the first")
    func backStepsBetweenThePagesAndDoesNothingOnTheFirst() {
        let vm = makeFixture().vm
        vm.onEvent(.backClicked)
        #expect(vm.state.stepIndex == 0)
        #expect(vm.state.canGoBack == false)

        vm.onEvent(.nextClicked)
        #expect(vm.state.canGoBack)
        vm.onEvent(.backClicked)

        #expect(vm.state.step == .welcome)
    }

    /// `OnboardingViewModelTest.kt:250-267`.
    @Test("an unusable measurement blocks the page but a blank one does not")
    func anUnusableMeasurementBlocksThePageButABlankOneDoesNot() {
        let vm = makeFixture().vm
        vm.onEvent(.nextClicked)
        vm.onEvent(.sexSelected(.male))

        vm.onEvent(.heightChanged("7"))
        #expect(vm.state.showInvalidHeight)
        #expect(vm.state.canContinue == false)

        vm.onEvent(.heightChanged(""))
        #expect(vm.state.showInvalidHeight == false)
        #expect(vm.state.canContinue)

        vm.onEvent(.weightChanged("3"))
        #expect(vm.state.showInvalidWeight)
        #expect(vm.state.canContinue == false)
    }

    /// `OnboardingViewModelTest.kt:269-300`.
    @Test("finishing writes the profile, the first weight and the completion flag")
    func finishingWritesTheProfileTheFirstWeightAndTheCompletionFlag() async {
        let fixture = makeFixture()
        let vm = fixture.vm
        vm.onEvent(.nextClicked)
        vm.onEvent(.nameChanged("  Ada  "))
        vm.onEvent(.sexSelected(.female))
        vm.onEvent(.birthDateSelected(LocalDate(year: 1990, month: 6, day: 15).epochDay))
        vm.onEvent(.heightChanged("170"))
        // A Turkish keyboard produces a comma.
        vm.onEvent(.weightChanged("72,4"))
        vm.onEvent(.nextClicked)
        vm.onEvent(.healthNotesChanged("Pollen allergy"))

        #expect(vm.state.step == .healthAndPermissions)
        #expect(vm.state.isLastStep)
        vm.onEvent(.nextClicked)
        await waitUntil("the completion flag to be written") { fixture.preferences.completed }

        let saved = fixture.repository.profile
        #expect(saved?.id == "default-profile")
        #expect(saved?.displayName == "Ada")
        #expect(saved?.sex == .female)
        #expect(saved?.birthDate == LocalDate(year: 1990, month: 6, day: 15))
        #expect(saved?.heightCm == 170.0)
        #expect(saved?.healthNotes == "Pollen allergy")

        #expect(
            fixture.vitals.recorded == [
                RecordedWeight(kilograms: 72.4, epochMs: Self.now.epochMilliseconds, timeZoneId: "Europe/Istanbul")
            ]
        )
        #expect(fixture.preferences.completed)
        // Ruling 7: the profile lands first and the flag last, so a process death midway replays
        // the flow instead of stranding a half-filled profile behind a closed gate.
        #expect(fixture.orderLog.writes == [.profile, .weight, .completionFlag])
    }

    /// `OnboardingViewModelTest.kt:302-313`.
    @Test("a skipped weight writes no measurement and blank notes stay null")
    func aSkippedWeightWritesNoMeasurementAndBlankNotesStayNull() async {
        let fixture = makeFixture(includeNotificationStep: false)
        let vm = fixture.vm
        vm.goToLastPage()
        vm.onEvent(.healthNotesChanged("   "))
        vm.onEvent(.nextClicked)
        await waitUntil("the completion flag to be written") { fixture.preferences.completed }

        #expect(fixture.vitals.recorded.isEmpty)
        #expect(fixture.repository.profile?.healthNotes == nil)
        #expect(fixture.preferences.completed)
        #expect(fixture.orderLog.writes == [.profile, .completionFlag])
    }

    // MARK: - iOS-only

    /// **iOS-only — no Kotlin twin.** `ProfileRepository.saveProfile(_:)` and
    /// `VitalsQuickEntry.recordWeight(…)` are `throws` on iOS (`ProfileRepository.swift:24-31`,
    /// `VitalsQuickEntry.swift:13`) where the Kotlin `suspend fun`s cannot fail, so
    /// `OnboardingViewModelTest.kt` has no case to port for the abort path. Divergence 3 in
    /// `OnboardingViewModel.swift` is what this pins: a throw stops the sequence *before*
    /// `preferences.setCompleted()`, so the gate stays shut and ruling 7's "replay rather than
    /// strand" still holds, and it clears `isSaving`, so the last page is tappable again rather
    /// than permanently disabled.
    ///
    /// A `false` **return** from `recordWeight` is a different thing and is deliberately not
    /// covered here: Kotlin discards it (`OnboardingViewModel.kt:139-145`) and so does the port, so
    /// an out-of-range weight still completes the flow.
    @Test(
        "a failing write aborts before the completion flag and leaves the page retryable",
        arguments: [FailingWrite.profile, .weight]
    )
    func aFailingWriteAbortsBeforeTheCompletionFlagAndLeavesTheStepRetryable(failing: FailingWrite) async {
        let fixture = makeFixture(failing: failing)
        let vm = fixture.vm
        vm.onEvent(.nextClicked)
        vm.onEvent(.sexSelected(.male))
        // A weight that parses, so `finish()` actually reaches `recordWeight`.
        vm.onEvent(.weightChanged("72,4"))
        vm.onEvent(.nextClicked)
        #expect(vm.state.step == .healthAndPermissions)

        vm.onEvent(.nextClicked)
        #expect(vm.state.isSaving, "the write is in flight")
        await waitUntil("the failed write to reopen the last page") { vm.state.isSaving == false }

        #expect(fixture.preferences.completed == false, "the completion flag must not be written")
        #expect(fixture.orderLog.writes == failing.writesBeforeTheFailure)
        #expect(vm.state.isSaving == false)
        // The flow never left its last page, and the button is live again.
        #expect(vm.state.step == .healthAndPermissions)
        #expect(vm.state.canContinue)
    }
}

/// Which of `finish()`'s two throwing collaborators fails — iOS-only, no Kotlin twin.
enum FailingWrite: Sendable, Equatable {
    case profile
    case weight

    /// What made it into the log before the throw: nothing when the profile write fails, the
    /// profile alone when the weight write does. The completion flag is in neither.
    var writesBeforeTheFailure: [FinishWrite] {
        switch self {
        case .profile: []
        case .weight: [.profile]
        }
    }
}

/// `OnboardingViewModelTest.kt:315-323` — walks to the last page, answering the one mandatory
/// question on the way.
@MainActor
extension OnboardingViewModel {
    fileprivate func goToLastPage(sourceLocation: SourceLocation = #_sourceLocation) {
        onEvent(.nextClicked)
        onEvent(.sexSelected(.male))
        onEvent(.nextClicked)
        if state.step != .healthAndPermissions {
            Issue.record("stuck on \(state.step)", sourceLocation: sourceLocation)
        }
    }
}
