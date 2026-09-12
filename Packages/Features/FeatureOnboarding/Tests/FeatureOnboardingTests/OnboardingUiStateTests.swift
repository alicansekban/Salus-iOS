// Ported 1:1 from
// `feature/onboarding/src/test/kotlin/com/alicansekban/salus/feature/onboarding/ui/
// OnboardingUiStateTest.kt`, all nine cases by name (backtick → camelCase).
//
// The header's counter and its three segments, and both footer buttons, are read off derived
// state — these are the tests that keep them honest (`OnboardingUiStateTest.kt:10-13`).

import SalusModel
import Testing

@testable import FeatureOnboarding

@Suite("OnboardingUiState")
struct OnboardingUiStateTests {
    /// `OnboardingUiStateTest.kt:16-20` — a state whose page list is every page and whose
    /// `stepIndex` points at the given one.
    private func stateAt(_ step: OnboardingStep, sex: Sex? = nil) -> OnboardingUiState {
        OnboardingUiState(
            steps: OnboardingStep.allCases,
            stepIndex: OnboardingStep.allCases.firstIndex(of: step) ?? 0,
            sex: sex
        )
    }

    /// `OnboardingUiStateTest.kt:22-28`.
    @Test("the counter runs one to three with welcome as the first page")
    func theCounterRunsOneToThreeWithWelcomeAsTheFirstPage() {
        #expect(stateAt(.welcome).stepCount == 3)
        #expect(stateAt(.welcome).stepNumber == 1)
        #expect(stateAt(.personalDetails).stepNumber == 2)
        #expect(stateAt(.healthAndPermissions).stepNumber == 3)
    }

    /// `OnboardingUiStateTest.kt:30-35`.
    @Test("only the last page finishes")
    func onlyTheLastPageFinishes() {
        #expect(stateAt(.welcome).isLastStep == false)
        #expect(stateAt(.personalDetails).isLastStep == false)
        #expect(stateAt(.healthAndPermissions).isLastStep)
    }

    /// `OnboardingUiStateTest.kt:37-42`.
    @Test("the flow can be stepped through but never escaped")
    func theFlowCanBeSteppedThroughButNeverEscaped() {
        #expect(stateAt(.welcome).canGoBack == false)
        #expect(stateAt(.personalDetails).canGoBack)
        #expect(stateAt(.healthAndPermissions).canGoBack)
    }

    /// `OnboardingUiStateTest.kt:44-49`.
    @Test("the cover has nothing to skip")
    func theCoverHasNothingToSkip() {
        #expect(stateAt(.welcome).isSkippable == false)
        #expect(stateAt(.personalDetails, sex: .female).isSkippable)
        #expect(stateAt(.healthAndPermissions).isSkippable)
    }

    /// `OnboardingUiStateTest.kt:51-60`.
    @Test("sex gates both ways out of the personal page")
    func sexGatesBothWaysOutOfThePersonalPage() {
        let blocked = stateAt(.personalDetails)
        #expect(blocked.canContinue == false)
        #expect(blocked.canSkip == false)

        let answered = stateAt(.personalDetails, sex: .other)
        #expect(answered.canContinue)
        #expect(answered.canSkip)
    }

    /// `OnboardingUiStateTest.kt:62-76`.
    @Test("a measurement that cannot be read blocks the page, a blank one does not")
    func aMeasurementThatCannotBeReadBlocksThePageABlankOneDoesNot() {
        var base = stateAt(.personalDetails, sex: .male)
        #expect(base.canContinue)

        var tooShort = base
        tooShort.heightText = "7"
        #expect(tooShort.showInvalidHeight)
        #expect(tooShort.canContinue == false)

        var tooLight = base
        tooLight.weightText = "3"
        #expect(tooLight.showInvalidWeight)
        #expect(tooLight.canContinue == false)

        // A Turkish keyboard produces a comma, and `MeasurementInput` reads it.
        base.heightText = "170,5"
        #expect(base.showInvalidHeight == false)
    }

    /// `OnboardingUiStateTest.kt:78-82`.
    @Test("an unreadable measurement is the personal page's problem alone")
    func anUnreadableMeasurementIsThePersonalPagesProblemAlone() {
        var last = stateAt(.healthAndPermissions)
        last.heightText = "7"
        #expect(last.canContinue)
    }

    /// `OnboardingUiStateTest.kt:84-89`.
    @Test("saving closes every door")
    func savingClosesEveryDoor() {
        var saving = stateAt(.healthAndPermissions)
        saving.isSaving = true
        #expect(saving.canContinue == false)
        #expect(saving.canSkip == false)
    }

    /// `OnboardingUiStateTest.kt:91-97`.
    @Test("the cycle note is offered to everyone the cycle feature is for")
    func theCycleNoteIsOfferedToEveryoneTheCycleFeatureIsFor() {
        #expect(stateAt(.personalDetails, sex: .female).showCycleNote)
        #expect(stateAt(.personalDetails, sex: .other).showCycleNote)
        #expect(stateAt(.personalDetails, sex: .male).showCycleNote == false)
        #expect(stateAt(.personalDetails).showCycleNote == false)
    }
}
