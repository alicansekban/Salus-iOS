// Ported 1:1 from
// `feature/onboarding/src/main/kotlin/com/alicansekban/salus/feature/onboarding/ui/
// OnboardingViewModel.kt` (M15/M16: `OnboardingViewModel.kt:24-160`).
//
// The page machine itself lives on `OnboardingUiState` (already ported); this is the event gate,
// the one permission the flow ever asks for and the one write it performs. Five divergences from
// the Kotlin twin, all forced by the platform and recorded here so a reader sees them without
// leaving the file:
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
//      last page can be retried — the same "replay rather than strand" property ruling 7 asks for,
//      applied to a failure the Kotlin has no path for.
//   4. **`Profile.copy(…)` → an explicit rebuild.** `SalusModel.Profile` is a `let`-only struct with
//      no `copy`, so the five answered fields are written and `id`/`isDefault` are carried over from
//      the existing row by hand. Same result as the Kotlin `copy`, spelled out.
//   5. **`Channel<OnboardingEffect>` → a buffered `pendingEffects` queue** (`OnboardingViewModel.kt:41-42`).
//      `@Observable` has no subscription-count hook, so the effect accumulates in a published array
//      and the Route drains it with ``consumeEffects()`` — the shape `MoreViewModel` (iOS-M8) set
//      for exactly this Kotlin idiom. A queue rather than a single slot because the drain and the
//      append must not race; in practice the flow ever queues one.

import Foundation
import Observation
import SalusCommon
import SalusModel
import SalusProfile

/// Drives the onboarding flow (`OnboardingViewModel.kt:24-160`).
@MainActor
@Observable
public final class OnboardingViewModel {
    /// `OnboardingViewModel.kt:33-39` — what the screen draws.
    public private(set) var state: OnboardingUiState

    /// `Channel.BUFFERED`'s twin (divergence 5): the effects fired while the screen was not
    /// listening, waiting for ``consumeEffects()`` to drain them in order. Nothing is dropped.
    public private(set) var pendingEffects: [OnboardingEffect] = []

    private let profileRepository: any ProfileRepository
    private let vitalsQuickEntry: any VitalsQuickEntry
    private let preferences: any OnboardingPreferences
    private let clock: any SalusClock

    /// The five parameters are the five Koin resolves for `viewModelOf(::OnboardingViewModel)`, in
    /// the Kotlin order (`OnboardingViewModel.kt:24-31`).
    ///
    /// - Parameter includeNotificationStep: false where the platform has no notification permission
    ///   to ask for and the switch is pointless (`OnboardingViewModel.kt:29-30`). iOS has no
    ///   API-level gate — `UNUserNotificationCenter` exists on every supported version — so it
    ///   defaults to true and the composition root never passes it; the parameter stays so the
    ///   hidden switch row is still testable. The default is the one addition to the Kotlin
    ///   signature. It seeds `remindersAvailable`, never the page list: all three pages are always
    ///   there, and only the switch row goes (`OnboardingUiState.kt:30-34`).
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
            steps: OnboardingStep.allCases,
            remindersAvailable: includeNotificationStep
        )
    }

    /// `OnboardingViewModel.kt:44-70`. `lastStepDirection` is iOS-only (no Kotlin twin): set from
    /// the event so the page transition reads the correct direction on the first body eval — see
    /// `OnboardingUiState`'s type-level doc comment.
    public func onEvent(_ event: OnboardingEvent) {
        switch event {
        case .nextClicked:
            state.lastStepDirection = .forward
            advance()

        case .backClicked:
            state.stepIndex = max(state.stepIndex - 1, 0)
            state.lastStepDirection = .backward

        case .skipClicked:
            state.lastStepDirection = .forward
            skip()

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

        case let .remindersToggled(enabled):
            state.remindersEnabled = enabled
        }
    }

    /// Drains the buffered effects in order, leaving the queue empty — the twin of collecting
    /// Kotlin's `Channel<OnboardingEffect>` until it suspends (`OnboardingScreen.kt:56-67`).
    @discardableResult
    public func consumeEffects() -> [OnboardingEffect] {
        let drained = pendingEffects
        pendingEffects.removeAll()
        return drained
    }

    /// `OnboardingViewModel.kt:72-85`.
    private func advance() {
        guard state.canContinue else { return }
        if state.isLastStep {
            // The permission is asked for on the way out, and the answer is not waited on:
            // a denial leaves a working app with its reminders off, not a stuck gate.
            if state.remindersAvailable, state.remindersEnabled {
                pendingEffects.append(.requestNotificationPermission)
            }
            finish()
        } else {
            state.stepIndex += 1
        }
    }

    /// Skipping is answering "nothing": whatever the page collected is cleared, so a half-typed
    /// field never lands in the profile behind the user's back. The last page skips the
    /// permission with it — asking for one after "later" would be the opposite of the answer
    /// (`OnboardingViewModel.kt:87-115`).
    private func skip() {
        guard state.canSkip else { return }
        switch state.step {
        case .welcome:
            break

        case .personalDetails:
            state.name = ""
            state.birthDateEpochDay = nil
            state.heightText = ""
            state.weightText = ""
            state.stepIndex += 1

        case .healthAndPermissions:
            state.healthNotes = ""
            finish()
        }
    }

    /// Writes the profile first and the completion flag last, so a process death midway
    /// replays the flow instead of stranding a half-filled profile behind a closed gate.
    ///
    /// `OnboardingViewModel.kt:117-149`.
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
                // Clearing `isSaving` re-enables the last page rather than leaving the user
                // looking at a permanently disabled button.
                state.isSaving = false
            }
        }
    }

    /// The Kotlin `(existing ?: emptyProfile()).copy(…)` (`OnboardingViewModel.kt:127-135`), spelled
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
    /// `OnboardingViewModel.kt:151-160`.
    ///
    /// Kotlin reads `SalusDatabase.DEFAULT_PROFILE_ID` directly; a feature on this side never
    /// imports `SalusDatabase` (CLAUDE.md — records and DAOs live there), so the id comes through
    /// `SalusProfile`'s ``ProfileRepositoryDefaults``, the twin of the Kotlin companion constant
    /// that exists "for callers that have no Room dependency" (`ProfileRepository.kt:25-28`).
    private static func emptyProfile() -> Profile {
        Profile(
            id: ProfileRepositoryDefaults.defaultProfileId,
            displayName: "",
            birthDate: nil,
            sex: nil,
            heightCm: nil,
            healthNotes: nil,
            isDefault: true
        )
    }
}
