// Ported 1:1 from `feature/settings/src/test/kotlin/com/alicansekban/salus/feature/settings/
// ui/profile/ProfileViewModelTest.kt` — all eight cases, in the Kotlin order, under the Kotlin
// names in camelCase.
//
// `advanceUntilIdle()` has no twin (Swift Testing has no virtual scheduler), so every case waits on
// the condition it is about to assert with `waitUntil`, the shape `MoreViewModelTests` uses.
// `FakeProfileRepository` is `MoreFakes.swift`'s, extended with the `saved` list the Kotlin fake
// keeps; `FakeNavigator` is the `FeatureVitalsTests` recorder, copied per the M7 precedent.

import SalusModel
import SalusProfile
import Testing

@testable import FeatureSettings

/// `ProfileViewModelTest.kt:49-57` — the row every case starts from.
private let stored = Profile(
    id: "default",
    displayName: "Ayşe",
    birthDate: LocalDate(year: 1990, month: 5, day: 17),
    sex: .female,
    heightCm: 165,
    healthNotes: "Penicillin allergy",
    isDefault: true
)

@MainActor
@Suite("ProfileViewModel")
struct ProfileViewModelTests {
    /// `ProfileViewModelTest.kt:64-68`.
    private func setUp(
        profile: Profile? = stored
    ) -> (ProfileViewModel, FakeProfileRepository, FakeNavigator) {
        let repository = FakeProfileRepository(profile: profile)
        let navigator = FakeNavigator()
        return (
            ProfileViewModel(profileRepository: repository, navigator: navigator.navigator),
            repository,
            navigator
        )
    }

    @Test("loads the stored profile into the form")
    func loadsTheStoredProfileIntoTheForm() async {
        let (viewModel, _, navigator) = setUp()
        defer { navigator.stop() }
        await waitUntil("the profile to load") { !viewModel.state.isLoading }

        let state = viewModel.state
        #expect(!state.isLoading)
        #expect(state.name == "Ayşe")
        #expect(state.sex == .female)
        #expect(state.storedSex == .female)
        #expect(state.birthDateEpochDay == LocalDate(year: 1990, month: 5, day: 17).epochDay)
        // The point of `formatHeight`: "165", never "165.0".
        #expect(state.heightText == "165")
        #expect(state.healthNotes == "Penicillin allergy")
    }

    @Test("blank optional fields save as null and the stored id is kept")
    func blankOptionalFieldsSaveAsNullAndTheStoredIdIsKept() async throws {
        let (viewModel, repository, navigator) = setUp()
        defer { navigator.stop() }
        await waitUntil("the profile to load") { !viewModel.state.isLoading }

        viewModel.onEvent(.nameChanged("  Ayşe Y.  "))
        viewModel.onEvent(.heightChanged("   "))
        viewModel.onEvent(.healthNotesChanged(""))
        viewModel.onEvent(.saveClicked)
        await waitUntil("the write") { !repository.saved.isEmpty }

        let saved = try #require(repository.saved.first)
        #expect(repository.saved.count == 1)
        #expect(saved.id == "default")
        #expect(saved.isDefault)
        #expect(saved.displayName == "Ayşe Y.")
        #expect(saved.heightCm == nil)
        #expect(saved.healthNotes == nil)
        #expect(saved.sex == .female)
        await waitUntil("the pop") { navigator.commandLog == [.pop] }
    }

    @Test("an out-of-range height blocks the save")
    func anOutOfRangeHeightBlocksTheSave() async {
        let (viewModel, repository, navigator) = setUp()
        defer { navigator.stop() }
        await waitUntil("the profile to load") { !viewModel.state.isLoading }

        viewModel.onEvent(.heightChanged("300"))
        viewModel.onEvent(.saveClicked)
        await settle()

        #expect(viewModel.state.showInvalidHeight)
        #expect(repository.saved.isEmpty)
        #expect(navigator.commandLog.isEmpty)
    }

    @Test("female to male asks for confirmation before writing")
    func femaleToMaleAsksForConfirmationBeforeWriting() async throws {
        let (viewModel, repository, navigator) = setUp()
        defer { navigator.stop() }
        await waitUntil("the profile to load") { !viewModel.state.isLoading }

        viewModel.onEvent(.sexSelected(.male))
        #expect(viewModel.state.cycleVisibilityChange == .disappears)

        viewModel.onEvent(.saveClicked)
        await settle()
        #expect(viewModel.state.showSexChangeConfirm)
        #expect(repository.saved.isEmpty)

        viewModel.onEvent(.sexChangeConfirmed)
        await waitUntil("the write") { !repository.saved.isEmpty }
        #expect(try #require(repository.saved.first).sex == .male)
        await waitUntil("the pop") { navigator.commandLog == [.pop] }
    }

    @Test("a skipped sex set to male also asks for confirmation")
    func aSkippedSexSetToMaleAlsoAsksForConfirmation() async {
        let (viewModel, repository, navigator) = setUp(profile: stored.with(sex: nil))
        defer { navigator.stop() }
        await waitUntil("the profile to load") { !viewModel.state.isLoading }

        viewModel.onEvent(.sexSelected(.male))
        viewModel.onEvent(.saveClicked)
        await settle()

        #expect(viewModel.state.showSexChangeConfirm)
        #expect(repository.saved.isEmpty)
    }

    @Test("female to other keeps the cycle row and needs no confirmation")
    func femaleToOtherKeepsTheCycleRowAndNeedsNoConfirmation() async throws {
        let (viewModel, repository, navigator) = setUp()
        defer { navigator.stop() }
        await waitUntil("the profile to load") { !viewModel.state.isLoading }

        viewModel.onEvent(.sexSelected(.other))
        #expect(viewModel.state.cycleVisibilityChange == nil)

        viewModel.onEvent(.saveClicked)
        await waitUntil("the write") { !repository.saved.isEmpty }

        #expect(!viewModel.state.showSexChangeConfirm)
        #expect(try #require(repository.saved.first).sex == .other)
    }

    @Test("male back to female brings the row back without a dialog")
    func maleBackToFemaleBringsTheRowBackWithoutADialog() async throws {
        let (viewModel, repository, navigator) = setUp(profile: stored.with(sex: .male))
        defer { navigator.stop() }
        await waitUntil("the profile to load") { !viewModel.state.isLoading }

        viewModel.onEvent(.sexSelected(.female))
        #expect(viewModel.state.cycleVisibilityChange == .appears)

        viewModel.onEvent(.saveClicked)
        await waitUntil("the write") { !repository.saved.isEmpty }

        #expect(try #require(repository.saved.first).sex == .female)
    }

    @Test("cancelling the dialog restores the stored sex and writes nothing")
    func cancellingTheDialogRestoresTheStoredSexAndWritesNothing() async {
        let (viewModel, repository, navigator) = setUp()
        defer { navigator.stop() }
        await waitUntil("the profile to load") { !viewModel.state.isLoading }

        viewModel.onEvent(.sexSelected(.male))
        viewModel.onEvent(.saveClicked)
        await settle()
        viewModel.onEvent(.sexChangeDismissed)

        let state = viewModel.state
        #expect(!state.showSexChangeConfirm)
        #expect(state.sex == .female)
        #expect(state.cycleVisibilityChange == nil)
        #expect(repository.saved.isEmpty)
        #expect(navigator.commandLog.isEmpty)
    }

    // MARK: - iOS-only

    /// **iOS-only — no Kotlin twin.** `ProfileRepository.getProfile()` is `throws` on iOS
    /// (`ProfileRepository.swift:24`) where Kotlin's is a plain `suspend fun`, so the load has to
    /// tell a *failure* from an *absent row* — and `ProfileViewModelTest.kt` has no case for either
    /// because Kotlin's null-safe reads (`profile?.displayName.orEmpty()`, `:30-35`) make the
    /// distinction invisible there. Divergence 2 in `ProfileViewModel.swift` is what this pins: a
    /// nil row is **not** a failure, so `isLoading` clears and the form opens empty rather than
    /// spinning for ever.
    ///
    /// The save that follows pins the other half of the same corrupted-install path,
    /// `emptyProfile()` (`ProfileViewModel.kt:98-107`): with no row to copy, the write seeds
    /// `ProfileRepositoryDefaults.defaultProfileId` and `isDefault`, so every table that hangs off
    /// `profile_id` still finds its parent.
    @Test("a missing profile row opens an empty form and saves back the seeded id")
    func aMissingProfileRowOpensAnEmptyFormAndSavesBackTheSeededId() async throws {
        let (viewModel, repository, navigator) = setUp(profile: nil)
        defer { navigator.stop() }
        await waitUntil("the load to finish") { !viewModel.state.isLoading }

        #expect(viewModel.state == ProfileUiState(isLoading: false))

        viewModel.onEvent(.nameChanged("Ayşe"))
        viewModel.onEvent(.saveClicked)
        await waitUntil("the write") { !repository.saved.isEmpty }

        let saved = try #require(repository.saved.first)
        #expect(saved.id == ProfileRepositoryDefaults.defaultProfileId)
        #expect(saved.isDefault)
        #expect(saved.displayName == "Ayşe")
        #expect(saved.sex == nil)
        #expect(saved.birthDate == nil)
        #expect(saved.heightCm == nil)
        #expect(saved.healthNotes == nil)
        await waitUntil("the pop") { navigator.commandLog == [.pop] }
    }

    // MARK: - Helpers

    /// `advanceUntilIdle()` where there is nothing to wait *for* — the three cases that assert a
    /// write never happened have to give the write its chance first, or they would pass on a
    /// ViewModel that simply had not got there yet.
    private func settle(hops: Int = 50) async {
        for _ in 0 ..< hops {
            await Task.yield()
        }
    }
}

/// `Profile` is immutable and has no `copy`; the two cases that vary one field say so here rather
/// than re-listing the seven arguments (`ProfileViewModelTest.kt:141`, `:169`).
extension Profile {
    fileprivate func with(sex: Sex?) -> Profile {
        Profile(
            id: id,
            displayName: displayName,
            birthDate: birthDate,
            sex: sex,
            heightCm: heightCm,
            healthNotes: healthNotes,
            isDefault: isDefault
        )
    }
}
