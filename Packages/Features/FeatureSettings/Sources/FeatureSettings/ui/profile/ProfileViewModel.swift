// Ported 1:1 from `feature/settings/src/main/kotlin/com/alicansekban/salus/feature/settings/
// ui/profile/ProfileViewModel.kt`.
//
// Three divergences from the Kotlin twin, all forced by the platform and recorded here so a reader
// sees them without leaving the file:
//
//   1. **`MutableStateFlow` → `@Observable`.** The state is a stored property SwiftUI observes
//      directly, so `_state.update { it.copy(…) }` becomes a mutation of `state`. Same UDF, same
//      single writer: nothing outside this type assigns it (`private(set)`).
//   2. **The repository throws.** `ProfileRepository` is `async throws` on iOS (its doc records
//      why: a Room-backed `Flow` lets a failure reach the collector, and swallowing it here would
//      show an empty form where Android shows a failure). Kotlin's `getProfile()` is a plain
//      `suspend fun` whose exception would take the `viewModelScope` — and the process — down, so
//      there is no Kotlin behaviour to copy. The load leaves `isLoading` true on failure, which is
//      what `MoreViewModel` does for the same reason and what Android's `stateIn` initial value
//      shows anyway.
//   3. **A failed write clears `isSaving`.** Kotlin never clears it because the save is the last
//      thing that happens before `pop()`; a throw there would crash rather than return. Here a
//      failed write leaves the screen standing, so the flag is cleared and the save button comes
//      back — a form the user cannot resubmit is worse than one that lets them try again.
//
// `viewModelScope.launch` becomes an unstructured `Task` on the main actor. The type is
// `@MainActor`, so every mutation of `state` and every read of it happens there.

import Foundation
import Observation
import SalusCommon
import SalusModel
import SalusNavigation
import SalusProfile

/// Drives the profile editor (`ProfileViewModel.kt:16-108`).
@MainActor
@Observable
public final class ProfileViewModel {
    /// `ProfileViewModel.kt:21-22` — what the screen draws.
    public private(set) var state = ProfileUiState()

    private let profileRepository: any ProfileRepository
    private let navigator: Navigator

    /// The two parameters are the two Koin resolves for `viewModelOf(::ProfileViewModel)`, in the
    /// Kotlin order (`ProfileViewModel.kt:16-19`).
    public init(profileRepository: any ProfileRepository, navigator: Navigator) {
        self.profileRepository = profileRepository
        self.navigator = navigator
        // `init { viewModelScope.launch { … } }` (`ProfileViewModel.kt:24-39`): loaded once, not
        // observed. The editor is a form — re-seeding it under the user's fingers because another
        // screen wrote the row is exactly what a form must not do.
        load()
    }

    // `ProfileViewModel.kt:41-73`.
    public func onEvent(_ event: ProfileEvent) {
        switch event {
        case let .nameChanged(text):
            state.name = text

        case let .sexSelected(sex):
            state.sex = sex

        case let .birthDateSelected(epochDay):
            state.birthDateEpochDay = epochDay

        case let .heightChanged(text):
            state.heightText = text

        case let .healthNotesChanged(text):
            state.healthNotes = text

        // The dialog guards exactly the change that takes a feature away. Anything else — including
        // bringing the Cycle row back — is saved straight away (`ProfileViewModel.kt:51-61`).
        case .saveClicked:
            guard !state.showInvalidHeight, !state.isSaving else { return }
            if state.cycleVisibilityChange == .disappears {
                state.showSexChangeConfirm = true
            } else {
                save()
            }

        case .sexChangeConfirmed:
            state.showSexChangeConfirm = false
            save()

        // Backing out puts the stored value back so the inline warning disappears too: the form
        // must not keep advertising a change that was just declined (`ProfileViewModel.kt:68-71`).
        case .sexChangeDismissed:
            state.showSexChangeConfirm = false
            state.sex = state.storedSex
        }
    }

    /// `ProfileViewModel.kt:25-38`.
    private func load() {
        Task { [weak self, profileRepository] in
            do {
                let profile = try await profileRepository.getProfile()
                guard let self else { return }
                state = Self.form(from: profile)
            } catch {
                // Divergence 2: a failed read leaves the form loading rather than showing an empty
                // one that would overwrite the row on the next save.
            }
        }
    }

    /// `ProfileViewModel.kt:27-37` — every `?.`/`orEmpty()` in one place. A missing row (which only
    /// a corrupted install produces) still clears `isLoading`: the form opens empty and saving it
    /// seeds the row, exactly as Kotlin's null-safe reads do.
    ///
    /// A whole new state rather than Kotlin's `it.copy(…)`, and it is only safe because the two
    /// members `copy` would have preserved — `isSaving`, `showSexChangeConfirm` — are `false` at
    /// load time on both platforms: this runs once, from `init`, before any event can set either.
    /// If the load ever becomes re-runnable (an observation, a pull-to-refresh), this has to become
    /// a copy or it will clear a dialog the user is looking at.
    private static func form(from profile: Profile?) -> ProfileUiState {
        guard let profile else { return ProfileUiState(isLoading: false) }
        return ProfileUiState(
            isLoading: false,
            name: profile.displayName,
            sex: profile.sex,
            birthDateEpochDay: profile.birthDate?.epochDay,
            heightText: profile.heightCm.map(formatHeight) ?? "",
            healthNotes: profile.healthNotes ?? "",
            storedSex: profile.sex
        )
    }

    /// Copies the stored row rather than building a new one: `id` and `isDefault` must survive,
    /// because every other table hangs off `profile_id`. A blank optional field saves as `nil`,
    /// exactly what a skipped onboarding step writes (`ProfileViewModel.kt:75-96`).
    ///
    /// **The form is captured synchronously, before the `Task`.** Kotlin reads `_state.value`
    /// *inside* `viewModelScope.launch`, which is safe there because nothing else runs between the
    /// call and the coroutine's first resumption. Here the `Task` body cannot start until the
    /// current main-actor turn ends, so any event delivered later in that same turn would be read
    /// instead of the form the user submitted — which is exactly what the confirm button's
    /// `.sexChangeDismissed` used to do, writing the *old* sex (review C1). Reading `state` once,
    /// here, makes the write independent of anything that happens after the tap.
    private func save() {
        let form = state
        state.isSaving = true
        Task { [weak self, profileRepository, navigator] in
            do {
                let existing = try await profileRepository.getProfile() ?? Self.emptyProfile()
                try await profileRepository.saveProfile(
                    Profile(
                        id: existing.id,
                        displayName: form.name.trimmingCharacters(in: .whitespacesAndNewlines),
                        birthDate: form.birthDateEpochDay.map(LocalDate.init(epochDay:)),
                        sex: form.sex,
                        heightCm: MeasurementInput.parseHeightCm(form.heightText),
                        healthNotes: Self.blankToNil(form.healthNotes),
                        isDefault: existing.isDefault
                    )
                )
                navigator.pop()
            } catch {
                // Divergence 3: the screen is still on top, so give the user their button back.
                self?.state.isSaving = false
            }
        }
    }

    /// The row is seeded on database creation; this only guards a corrupted install
    /// (`ProfileViewModel.kt:98-107`).
    ///
    /// `ProfileRepositoryDefaults.defaultProfileId` is the twin of Kotlin's
    /// `ProfileRepository.DEFAULT_PROFILE_ID` (`ProfileRepository.kt:25-28`), which is where the
    /// Kotlin reads it too — a feature never reaches into the database package for a constant.
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

    /// `form.healthNotes.trim().takeIf { it.isNotEmpty() }` (`ProfileViewModel.kt:91`).
    private static func blankToNil(_ text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    /// "165" rather than "165.0": the field is typed by hand and read back the same way
    /// (`ProfileViewModel.kt:110-112`).
    private static func formatHeight(_ centimetres: Double) -> String {
        centimetres.truncatingRemainder(dividingBy: 1) == 0
            ? String(Int64(centimetres))
            : String(centimetres)
    }
}
