import Testing

@testable import FeatureOnboarding

/// The twin of Android's
/// `feature/onboarding/src/test/kotlin/com/alicansekban/salus/feature/onboarding/ui/OnboardingUiStateTest.kt`,
/// ported 1:1 by name. The header's title, counter and bar are all read off derived state, so
/// these are the tests that keep the header honest when the step list changes.
@Suite("OnboardingUiState")
struct OnboardingUiStateTests {
    /// The Kotlin twin's `stateAt(step)` helper: a state whose step list is every step and whose
    /// `stepIndex` points at the given one.
    private func stateAt(_ step: OnboardingStep) -> OnboardingUiState {
        OnboardingUiState(
            steps: OnboardingStep.allCases,
            stepIndex: OnboardingStep.allCases.firstIndex(of: step) ?? 0
        )
    }

    @Test("welcome has no section")
    func welcomeHasNoSection() {
        #expect(stateAt(.welcome).section == nil)
    }

    @Test("every step maps to its section")
    func everyStepMapsToItsSection() {
        let expected: [OnboardingStep: OnboardingSection] = [
            .name: .personalDetails,
            .sex: .personalDetails,
            .birthDate: .personalDetails,
            .height: .personalDetails,
            .weight: .personalDetails,
            .healthNotes: .healthNotes,
            .notifications: .privacy
        ]
        for (step, section) in expected {
            #expect(stateAt(step).section == section, "section of \(step)")
        }
    }

    @Test("welcome is outside the counter")
    func welcomeIsOutsideTheCounter() {
        let welcome = stateAt(.welcome)
        #expect(welcome.stepNumber == 0)
        #expect(welcome.progress == 0)
    }

    @Test("the counter runs one to seven over the collecting steps")
    func theCounterRunsOneToSevenOverTheCollectingSteps() {
        #expect(stateAt(.name).stepCount == 7)
        #expect(stateAt(.name).stepNumber == 1)
        #expect(stateAt(.notifications).stepNumber == 7)
        #expect(stateAt(.notifications).progress == 1)
    }

    @Test("progress never goes backwards across the flow")
    func progressNeverGoesBackwardsAcrossTheFlow() {
        let progresses = OnboardingStep.allCases.map { stateAt($0).progress }
        for pair in zip(progresses, progresses.dropFirst()) {
            #expect(pair.1 > pair.0, "\(pair.0) -> \(pair.1)")
        }
    }

    @Test("a shortened step list still counts to its own end")
    func aShortenedStepListStillCountsToItsOwnEnd() {
        let shortened = OnboardingUiState(
            steps: [.welcome, .name, .sex],
            stepIndex: 2
        )
        #expect(shortened.stepCount == 2)
        #expect(shortened.stepNumber == 2)
        #expect(shortened.progress == 1)
    }
}
