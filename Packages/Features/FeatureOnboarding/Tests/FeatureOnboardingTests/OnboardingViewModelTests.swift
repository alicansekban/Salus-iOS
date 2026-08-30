// Ported 1:1 from
// `feature/onboarding/src/test/kotlin/com/alicansekban/salus/feature/onboarding/ui/
// OnboardingViewModelTest.kt`.
//
// All seven Kotlin cases port by name (backtick → camelCase). Four substitutions, all of them the
// house pattern the M7/M8 ViewModel tests already set:
//
//   1. `MainDispatcherRule` + `runTest`'s virtual scheduler → the cooperative pool. Each
//      `advanceUntilIdle()` becomes a `waitUntil` that yields the main actor until the named
//      condition holds (`FeatureSettings/Tests/.../WaitUntil.swift`).
//   2. `repository.profiles.value!!` → `repository.profile`, the lock-guarded read the fake exposes.
//   3. `Triple(72.4, now.toEpochMilliseconds(), "Europe/Istanbul")` → a named ``RecordedWeight``.
//   4. Ruling 7's ordering — profile write, then weight, then the completion flag — is asserted
//      through the shared ``FinishOrderLog``. The Kotlin test asserts the three writes happened but
//      not their order; the ruling makes the order binding, so it is pinned here.

import Foundation
import SalusCommon
import SalusModel
import SalusTesting
import Testing

@testable import FeatureOnboarding

@Suite("OnboardingViewModel")
@MainActor
struct OnboardingViewModelTests {
    /// `OnboardingViewModelTest.kt:79` — the instant the fixed clock stands at.
    private static let now = Date(epochMilliseconds: 1_750_000_000_000)

    /// The four fakes the Kotlin test holds as fields (`OnboardingViewModelTest.kt:76-80`), rebuilt
    /// per case so no state leaks across them. `FixedSalusClock`'s default zone is already
    /// `Europe/Istanbul`, the zone `OnboardingViewModelTest.kt:80` names.
    private struct Fixture {
        let vm: OnboardingViewModel
        let repository: FakeProfileRepository
        let vitals: FakeVitalsQuickEntry
        let preferences: FakeOnboardingPreferences
        let orderLog: FinishOrderLog
    }

    /// `OnboardingViewModelTest.kt:82-88`.
    private func makeFixture(includeNotificationStep: Bool = true) -> Fixture {
        let orderLog = FinishOrderLog()
        let repository = FakeProfileRepository(orderLog: orderLog)
        let vitals = FakeVitalsQuickEntry(orderLog: orderLog)
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

    /// `OnboardingViewModelTest.kt:90-97`.
    @Test("the notification step is dropped below API 33")
    func theNotificationStepIsDroppedBelowApi33() {
        #expect(makeFixture(includeNotificationStep: false).vm.state.steps.contains(.notifications) == false)
        #expect(makeFixture().vm.state.steps.contains(.notifications))
    }

    /// `OnboardingViewModelTest.kt:99-115`.
    @Test("sex is the one hard gate")
    func sexIsTheOneHardGate() {
        let vm = makeFixture().vm
        vm.onEvent(.nextClicked) // Welcome
        vm.onEvent(.nextClicked) // Name, skippable and empty

        #expect(vm.state.step == .sex)
        #expect(vm.state.canContinue == false)
        #expect(vm.state.isSkippable == false)

        vm.onEvent(.nextClicked)
        #expect(vm.state.step == .sex, "without a sex the flow stays put")

        vm.onEvent(.sexSelected(.female))
        vm.onEvent(.nextClicked)
        #expect(vm.state.step == .birthDate)
    }

    /// `OnboardingViewModelTest.kt:117-125`.
    @Test("back on the first step is a no-op")
    func backOnTheFirstStepIsANoOp() {
        let vm = makeFixture().vm

        vm.onEvent(.backClicked)

        #expect(vm.state.stepIndex == 0)
        #expect(vm.state.canGoBack == false)
    }

    /// `OnboardingViewModelTest.kt:127-139`.
    @Test("an unusable measurement blocks the step but a blank one does not")
    func anUnusableMeasurementBlocksTheStepButABlankOneDoesNot() {
        let vm = makeFixture().vm
        vm.goTo(.height)

        vm.onEvent(.heightChanged("7"))
        #expect(vm.state.showInvalidHeight)
        #expect(vm.state.canContinue == false)

        vm.onEvent(.heightChanged(""))
        #expect(vm.state.showInvalidHeight == false)
        #expect(vm.state.canContinue)
    }

    /// `OnboardingViewModelTest.kt:141-151`.
    @Test("skipping clears what the step collected")
    func skippingClearsWhatTheStepCollected() {
        let vm = makeFixture().vm
        vm.goTo(.name)

        vm.onEvent(.nameChanged("Ada"))
        vm.onEvent(.skipClicked)

        #expect(vm.state.name.isEmpty)
        #expect(vm.state.step == .sex)
    }

    /// `OnboardingViewModelTest.kt:153-188`.
    @Test("finishing writes the profile, the first weight and the completion flag")
    func finishingWritesTheProfileTheFirstWeightAndTheCompletionFlag() async {
        let fixture = makeFixture()
        let vm = fixture.vm
        vm.goTo(.name)
        vm.onEvent(.nameChanged("  Ada  "))
        vm.onEvent(.nextClicked)
        vm.onEvent(.sexSelected(.female))
        vm.onEvent(.nextClicked)
        vm.onEvent(.birthDateSelected(LocalDate(year: 1990, month: 6, day: 15).epochDay))
        vm.onEvent(.nextClicked)
        vm.onEvent(.heightChanged("170"))
        vm.onEvent(.nextClicked)
        // A Turkish keyboard produces a comma.
        vm.onEvent(.weightChanged("72,4"))
        vm.onEvent(.nextClicked)
        vm.onEvent(.healthNotesChanged("Pollen allergy"))
        vm.onEvent(.nextClicked)

        #expect(vm.state.step == .notifications)
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

    /// `OnboardingViewModelTest.kt:190-203`.
    @Test("a skipped weight writes no measurement and blank notes stay null")
    func aSkippedWeightWritesNoMeasurementAndBlankNotesStayNull() async {
        let fixture = makeFixture(includeNotificationStep: false)
        let vm = fixture.vm
        vm.goTo(.sex)
        vm.onEvent(.sexSelected(.male))
        vm.goTo(.healthNotes)
        vm.onEvent(.healthNotesChanged("   "))
        vm.onEvent(.nextClicked)
        await waitUntil("the completion flag to be written") { fixture.preferences.completed }

        #expect(fixture.vitals.recorded.isEmpty)
        #expect(fixture.repository.profile?.healthNotes == nil)
        #expect(fixture.preferences.completed)
        #expect(fixture.orderLog.writes == [.profile, .completionFlag])
    }
}

/// `OnboardingViewModelTest.kt:205-215` — walks forward through the flow, answering the one
/// mandatory question on the way.
@MainActor
extension OnboardingViewModel {
    fileprivate func goTo(_ target: OnboardingStep, sourceLocation: SourceLocation = #_sourceLocation) {
        while state.step != target {
            if state.step == .sex, state.sex == nil {
                onEvent(.sexSelected(.female))
            }
            let before = state.stepIndex
            onEvent(.nextClicked)
            guard state.stepIndex > before else {
                Issue.record("stuck on \(state.step)", sourceLocation: sourceLocation)
                return
            }
        }
    }
}
