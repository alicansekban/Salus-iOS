// Ported 1:1 from
// `feature/onboarding/src/main/kotlin/com/alicansekban/salus/feature/onboarding/ui/
// OnboardingViewModel.kt`.
//
// The step machine itself lives on `OnboardingUiState` (already ported); this is the event gate and
// the one write the flow performs. Four divergences from the Kotlin twin, all forced by the
// platform and recorded here so a reader sees them without leaving the file:
//
//   1. **`MutableStateFlow` → `@Observable`.** Kotlin holds `_state`/`state` and calls
//      `_state.update { it.copy(…) }`; iOS mutates the `@Observable` `state` in place, which is the
//      same value-semantics update SwiftUI observes. `@MainActor` because every mutation and every
//      read happens on the main actor, the shape every ported ViewModel in this tree takes.
//   2. **`viewModelScope.launch` → an unstructured `Task`.** There is no `viewModelScope` on iOS.
//      The task is deliberately *not* stored and cancelled on `deinit`: `finish()`'s three writes
//      are the one place this feature touches the database, and cancelling them halfway is exactly
//      the half-applied state ruling 7 is written to avoid. It is `@MainActor`-isolated (inherited
//      from the enclosing method), so it reads `state` without a hop.
//   3. **The repository throws.** `ProfileRepository.getProfile()`/`saveProfile(_:)` and
//      `VitalsQuickEntry.recordWeight(…)` are `throws` on iOS (`ProfileRepository.swift:24-31`,
//      `VitalsQuickEntry.swift:13`) where the Kotlin `suspend fun`s cannot fail. A throw aborts the
//      sequence *before* the completion flag and clears `isSaving`, so the flow stays open and the
//      final step can be retried — the same "replay rather than strand" property ruling 7 asks for,
//      applied to a failure the Kotlin has no path for.
//   4. **`Profile.copy(…)` → an explicit rebuild.** `SalusModel.Profile` is a `let`-only struct with
//      no `copy`, so the five answered fields are written and `id`/`isDefault` are carried over from
//      the existing row by hand. Same result as the Kotlin `copy`, spelled out.

import Foundation
import Observation
import SalusCommon
import SalusDatabase
import SalusModel
import SalusProfile

/// Drives the onboarding flow (`OnboardingViewModel.kt:21-121`).
@MainActor
@Observable
public final class OnboardingViewModel {
    /// `OnboardingViewModel.kt:30-37` — what the screen draws.
    public private(set) var state: OnboardingUiState

    private let profileRepository: any ProfileRepository
    private let vitalsQuickEntry: any VitalsQuickEntry
    private let preferences: any OnboardingPreferences
    private let clock: any SalusClock

    /// The five parameters are the five Koin resolves for `viewModelOf(::OnboardingViewModel)`, in
    /// the Kotlin order (`OnboardingViewModel.kt:21-28`).
    ///
    /// - Parameter includeNotificationStep: false where the platform has no notification permission
    ///   to ask for and the step is pointless (`OnboardingViewModel.kt:26-27`). iOS has no API-level
    ///   gate — `UNUserNotificationCenter` exists on every supported version — so it defaults to
    ///   true and the composition root never passes it; the parameter stays so the shortened flow
    ///   is still testable. The default is the one addition to the Kotlin signature.
    public init(
        profileRepository: any ProfileRepository,
        vitalsQuickEntry: any VitalsQuickEntry,
        preferences: any OnboardingPreferences,
        clock: any SalusClock,
        includeNotificationStep: Bool = true
    ) {
        self.profileRepository = profileRepository
        self.vitalsQuickEntry = vitalsQuickEntry
        self.preferences = preferences
        self.clock = clock
        state = OnboardingUiState(
            steps: OnboardingStep.allCases
                .filter { $0 != .notifications || includeNotificationStep }
        )
    }

    /// `OnboardingViewModel.kt:39-65`.
    public func onEvent(_ event: OnboardingEvent) {
        switch event {
        case .nextClicked:
            advance()

        case .backClicked:
            state.stepIndex = max(state.stepIndex - 1, 0)

        case .skipClicked:
            state.clearCurrentStep()
            advance()

        case let .nameChanged(value):
            state.name = value

        case let .sexSelected(sex):
            state.sex = sex

        case let .birthDateSelected(epochDay):
            state.birthDateEpochDay = epochDay

        case let .heightChanged(value):
            state.heightText = value

        case let .weightChanged(value):
            state.weightText = value

        case let .healthNotesChanged(value):
            state.healthNotes = value
        }
    }

    /// `OnboardingViewModel.kt:67-75`.
    private func advance() {
        guard state.canContinue else { return }
        if state.isLastStep {
            finish()
        } else {
            state.stepIndex += 1
        }
    }

    /// Writes the profile first and the completion flag last, so a process death midway
    /// replays the flow instead of stranding a half-filled profile behind a closed gate.
    ///
    /// `OnboardingViewModel.kt:77-109`.
    private func finish() {
        if state.isSaving {
            return
        }
        state.isSaving = true
        // Divergence 2: unstructured and unstored, so the three writes always run to the end.
        Task {
            let answers = state
            do {
                let existing = try await profileRepository.getProfile()
                try await profileRepository.saveProfile(Self.answered(answers, on: existing))

                // Weight is a measurement, not a profile attribute: it lands in the vitals
                // history so the weight chart starts from day one.
                if let kilograms = MeasurementInput.parseWeightKg(answers.weightText) {
                    _ = try await vitalsQuickEntry.recordWeight(
                        kilograms: kilograms,
                        epochMs: clock.now().epochMilliseconds,
                        timeZoneId: clock.timeZone().identifier
                    )
                }

                await preferences.setCompleted()
            } catch {
                // Divergence 3: nothing after the failing write ran, so the gate is still open.
                // Clearing `isSaving` re-enables the final step rather than leaving the user
                // looking at a permanently disabled button.
                state.isSaving = false
            }
        }
    }

    /// The Kotlin `(existing ?: emptyProfile()).copy(…)` (`OnboardingViewModel.kt:88-94`), spelled
    /// out because `Profile` has no `copy` — divergence 4. `id` and `isDefault` survive from the
    /// existing row; the other five fields are the flow's answers.
    private static func answered(_ answers: OnboardingUiState, on existing: Profile?) -> Profile {
        let base = existing ?? emptyProfile()
        let notes = answers.healthNotes.trimmingCharacters(in: .whitespacesAndNewlines)
        return Profile(
            id: base.id,
            displayName: answers.name.trimmingCharacters(in: .whitespacesAndNewlines),
            birthDate: answers.birthDateEpochDay.map { LocalDate(epochDay: $0) },
            sex: answers.sex,
            heightCm: MeasurementInput.parseHeightCm(answers.heightText),
            healthNotes: notes.isEmpty ? nil : notes,
            isDefault: base.isDefault
        )
    }

    /// The row is seeded on database creation; this only guards a corrupted install.
    /// `OnboardingViewModel.kt:111-120`.
    private static func emptyProfile() -> Profile {
        Profile(
            id: SalusDatabase.defaultProfileId,
            displayName: "",
            birthDate: nil,
            sex: nil,
            heightCm: nil,
            healthNotes: nil,
            isDefault: true
        )
    }
}

/// `OnboardingViewModel.kt:123-130` — a private extension in the Kotlin file too, so it stays here
/// rather than on the state type: clearing is the *skip event's* behaviour, not something the state
/// answers about itself. Welcome, Sex and Notifications collect nothing, so they are untouched
/// (Sex is not skippable at all).
extension OnboardingUiState {
    fileprivate mutating func clearCurrentStep() {
        switch step {
        case .name: name = ""
        case .birthDate: birthDateEpochDay = nil
        case .height: heightText = ""
        case .weight: weightText = ""
        case .healthNotes: healthNotes = ""
        case .notifications, .sex, .welcome: break
        }
    }
}
