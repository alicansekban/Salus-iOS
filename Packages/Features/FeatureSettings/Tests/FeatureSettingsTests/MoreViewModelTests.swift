// Ported 1:1 from
// `feature/settings/src/test/kotlin/com/alicansekban/salus/feature/settings/ui/more/
// MoreViewModelTest.kt`.
//
// The cases port by name, grouped exactly as the Kotlin test groups them (cycle visibility 4,
// settings + sheets 7, premium 4, doctor report 3, colour themes 6). The three dialog-era cases
// (`selectingAThemePersistsItAndClosesTheDialog`, `selectingALanguageAppliesTheLocaleAndClosesTheDialog`)
// were renamed and re-specified by the M15 sheet model — the pick applies under the sheet and the
// sheet stays open (plan ruling 1 / handover item 5). The two iOS-only cases that pin the effect
// **queue** — divergence (4), which the Kotlin `Channel` + `LaunchedEffect` collector makes
// unnecessary there — live in `MoreEffectQueueTests.swift`, so this suite stays the ported table
// and nothing else. Turbine's `state.test { awaitItem() }` becomes reading `viewModel.state` after
// `waitUntil`, and its `effects.test { awaitItem() }` becomes reading `pendingEffects` /
// `consumeEffects()` — the same substitution the M7 `ReminderHealthViewModelTests` made for
// `@Observable`, generalised to the buffered array.
//
// The `MainDispatcherRule` + `runTest` virtual scheduler becomes the cooperative pool: each
// `advanceUntilIdle()` is a `waitUntil` that yields the main actor until the named condition holds.
// `hotViewModel()` — a ViewModel with a live `state` subscriber — is spelled the same way, because
// `@Observable`'s observation starts in `init` rather than on first read, so every ViewModel is
// already "hot".

import Foundation
import SalusModel
import SalusPremium
import Testing

@testable import FeatureSettings

@Suite("MoreViewModel")
@MainActor
struct MoreViewModelTests {
    /// `MoreViewModelTest.kt:88-96` — the shared profile builder.
    private func profile(sex: Sex?) -> Profile {
        Profile(
            id: "default-profile",
            displayName: "Ada",
            birthDate: nil,
            sex: sex,
            heightCm: nil,
            healthNotes: nil,
            isDefault: true
        )
    }

    /// The five fakes the Kotlin test holds as fields, rebuilt per case so no state leaks across
    /// them (`MoreViewModelTest.kt:103-110`). The paywall is the real `PaywallController`, whose
    /// `request` the test reads exactly as the Kotlin test reads `paywallController.request.value`.
    private func makeViewModel(
        profile: Profile? = nil,
        premiumStatus: PremiumStatus = .free,
        preferences: FakeSettingsPreferences = FakeSettingsPreferences(),
        locale: FakeAppLocaleController = FakeAppLocaleController(),
        profileRepository: FakeProfileRepository? = nil,
        premium: FakePremiumRepository? = nil,
        paywall: PaywallController = PaywallController()
    ) -> (
        vm: MoreViewModel,
        repository: FakeProfileRepository,
        premium: FakePremiumRepository,
        preferences: FakeSettingsPreferences,
        locale: FakeAppLocaleController,
        paywall: PaywallController
    ) {
        let repository = profileRepository ?? FakeProfileRepository(profile: profile)
        let premiumRepository = premium ?? FakePremiumRepository(value: premiumStatus)
        let vm = MoreViewModel(
            profileRepository: repository,
            premiumRepository: premiumRepository,
            preferences: preferences,
            localeController: locale,
            paywallController: paywall
        )
        return (vm, repository, premiumRepository, preferences, locale, paywall)
    }

    // MARK: - Cycle visibility

    /// `MoreViewModelTest.kt:123-130`.
    @Test("cycle is hidden while the profile has not loaded")
    func cycleIsHiddenWhileTheProfileHasNotLoaded() {
        let fixture = makeViewModel()

        #expect(fixture.vm.state.isLoading)
        #expect(fixture.vm.state.showCycle == false)
    }

    /// `MoreViewModelTest.kt:132-144`.
    @Test("cycle is shown for female, other and unspecified profiles")
    func cycleIsShownForFemaleOtherAndUnspecifiedProfiles() async {
        for sex in [Sex.female, .other, nil] {
            let fixture = makeViewModel(profile: profile(sex: sex))

            await waitUntil("the profile to load and showCycle to settle for sex=\(String(describing: sex))") {
                !fixture.vm.state.isLoading && fixture.vm.state.showCycle
            }

            #expect(
                fixture.vm.state.showCycle,
                "sex=\(String(describing: sex)) should show cycle"
            )
        }
    }

    /// `MoreViewModelTest.kt:146-157`.
    @Test("cycle is hidden for a male profile")
    func cycleIsHiddenForAMaleProfile() async {
        let fixture = makeViewModel(profile: profile(sex: .male))

        await waitUntil("the male profile to load") { !fixture.vm.state.isLoading }

        #expect(fixture.vm.state.isLoading == false)
        #expect(fixture.vm.state.showCycle == false)
    }

    /// `MoreViewModelTest.kt:159-173`.
    @Test("changing sex updates visibility without recreating the view model")
    func changingSexUpdatesVisibilityWithoutRecreatingTheViewModel() async {
        let fixture = makeViewModel(profile: profile(sex: .male))

        await waitUntil("the male profile to load and hide cycle") {
            !fixture.vm.state.isLoading && !fixture.vm.state.showCycle
        }
        #expect(fixture.vm.state.showCycle == false)

        fixture.repository.setProfile(profile(sex: .female))

        await waitUntil("the female profile to show cycle") { fixture.vm.state.showCycle }
        #expect(fixture.vm.state.showCycle)
    }

    // MARK: - Settings, merged in from the former Settings screen

    /// `MoreViewModelTest.kt:194-209`.
    @Test("state carries the stored preferences")
    func stateCarriesTheStoredPreferences() async {
        let preferences = FakeSettingsPreferences(
            themeMode: .dark,
            appLockEnabled: true,
            secureScreenEnabled: true
        )
        let locale = FakeAppLocaleController(current: .english)
        let fixture = makeViewModel(
            preferences: preferences,
            locale: locale
        )

        await waitUntil("the stored preferences to load") { !fixture.vm.state.isLoading }

        #expect(fixture.vm.state.themeMode == .dark)
        #expect(fixture.vm.state.language == .english)
        #expect(fixture.vm.state.appLockEnabled)
        #expect(fixture.vm.state.secureScreenEnabled)
    }

    /// `MoreViewModelTest.kt:217-229` — both appearance rows open the one theme sheet, and it stays
    /// open while the mode is applied: the palette list below shares the sheet, so closing on the
    /// first tap would cost a second trip to change both.
    @Test("selecting a theme persists it and keeps the sheet open")
    func selectingAThemePersistsItAndKeepsTheSheetOpen() async {
        let fixture = makeViewModel()
        await waitUntil("the initial state to load") { !fixture.vm.state.isLoading }

        fixture.vm.onEvent(.themeSheetOpened)
        await waitUntil("the theme sheet to open") { fixture.vm.state.isThemeSheetOpen }
        #expect(fixture.vm.state.isThemeSheetOpen)

        fixture.vm.onEvent(.selectTheme(.dark))
        await waitUntil("the theme to persist") { fixture.preferences.themeModeValueSync == .dark }

        #expect(fixture.preferences.themeModeValueSync == .dark)
        #expect(fixture.vm.state.isThemeSheetOpen)
    }

    /// `MoreViewModelTest.kt:232-245`.
    @Test("the theme sheet opens and closes")
    func theThemeSheetOpensAndCloses() async {
        let fixture = makeViewModel()
        await waitUntil("the initial state to load") { !fixture.vm.state.isLoading }
        #expect(fixture.vm.state.isThemeSheetOpen == false)

        fixture.vm.onEvent(.themeSheetOpened)
        await waitUntil("the theme sheet to open") { fixture.vm.state.isThemeSheetOpen }
        #expect(fixture.vm.state.isThemeSheetOpen)

        fixture.vm.onEvent(.themeSheetDismissed)
        await waitUntil("the theme sheet to close") { !fixture.vm.state.isThemeSheetOpen }

        #expect(fixture.vm.state.isThemeSheetOpen == false)
    }

    /// `MoreViewModelTest.kt:249-261` — dismissing the sheet is not a selection: nothing is written
    /// on the way out.
    @Test("dismissing the theme sheet leaves the appearance untouched")
    func dismissingTheThemeSheetLeavesTheAppearanceUntouched() async {
        let fixture = makeViewModel()
        await waitUntil("the initial state to load") { !fixture.vm.state.isLoading }

        fixture.vm.onEvent(.themeSheetOpened)
        await waitUntil("the theme sheet to open") { fixture.vm.state.isThemeSheetOpen }

        fixture.vm.onEvent(.themeSheetDismissed)
        await waitUntil("the theme sheet to close") { !fixture.vm.state.isThemeSheetOpen }

        #expect(fixture.vm.state.isThemeSheetOpen == false)
        #expect(fixture.preferences.themeModeValueSync == .system)
        #expect(fixture.preferences.premiumThemeValueSync == .classic)
    }

    /// `MoreViewModelTest.kt:268-281` — the language sheet mirrors the theme sheet: the pick is
    /// applied under it and the sheet stays open, because the app repainting in the new language is
    /// the only preview there is.
    @Test("selecting a language applies the locale and keeps the sheet open")
    func selectingALanguageAppliesTheLocaleAndKeepsTheSheetOpen() async {
        let fixture = makeViewModel()
        await waitUntil("the initial state to load") { !fixture.vm.state.isLoading }

        fixture.vm.onEvent(.languageSheetOpened)
        await waitUntil("the language sheet to open") { fixture.vm.state.isLanguageSheetOpen }
        #expect(fixture.vm.state.isLanguageSheetOpen)

        fixture.vm.onEvent(.selectLanguage(.turkish))
        await waitUntil("the locale to apply") { fixture.locale.currentSync == .turkish }

        #expect(fixture.locale.currentSync == .turkish)
        #expect(fixture.locale.appliedSync == [.turkish])
        #expect(fixture.vm.state.isLanguageSheetOpen)
    }

    /// `MoreViewModelTest.kt:284-297`.
    @Test("the language sheet opens and closes")
    func theLanguageSheetOpensAndCloses() async {
        let fixture = makeViewModel()
        await waitUntil("the initial state to load") { !fixture.vm.state.isLoading }
        #expect(fixture.vm.state.isLanguageSheetOpen == false)

        fixture.vm.onEvent(.languageSheetOpened)
        await waitUntil("the language sheet to open") { fixture.vm.state.isLanguageSheetOpen }
        #expect(fixture.vm.state.isLanguageSheetOpen)

        fixture.vm.onEvent(.languageSheetDismissed)
        await waitUntil("the language sheet to close") { !fixture.vm.state.isLanguageSheetOpen }

        #expect(fixture.vm.state.isLanguageSheetOpen == false)
    }

    /// `MoreViewModelTest.kt:301-313` — dismissing the sheet is not a selection: nothing is applied
    /// on the way out.
    @Test("dismissing the language sheet leaves the locale untouched")
    func dismissingTheLanguageSheetLeavesTheLocaleUntouched() async {
        let fixture = makeViewModel()
        await waitUntil("the initial state to load") { !fixture.vm.state.isLoading }

        fixture.vm.onEvent(.languageSheetOpened)
        await waitUntil("the language sheet to open") { fixture.vm.state.isLanguageSheetOpen }

        fixture.vm.onEvent(.languageSheetDismissed)
        await waitUntil("the language sheet to close") { !fixture.vm.state.isLanguageSheetOpen }

        #expect(fixture.vm.state.isLanguageSheetOpen == false)
        #expect(fixture.locale.currentSync == .system)
        #expect(fixture.locale.appliedSync.isEmpty)
    }

    /// `MoreViewModelTest.kt:316-326`.
    @Test("security toggles persist")
    func securityTogglesPersist() async {
        let fixture = makeViewModel()
        await waitUntil("the initial state to load") { !fixture.vm.state.isLoading }

        fixture.vm.onEvent(.setAppLock(true))
        fixture.vm.onEvent(.setSecureScreen(true))
        await waitUntil("both security toggles to persist") {
            fixture.preferences.appLockEnabledValueSync && fixture.preferences.secureScreenEnabledValueSync
        }

        #expect(fixture.preferences.appLockEnabledValueSync)
        #expect(fixture.preferences.secureScreenEnabledValueSync)
    }

    // MARK: - Premium

    /// `MoreViewModelTest.kt:333-342`.
    @Test("state follows the entitlement")
    func stateFollowsTheEntitlement() async {
        let fixture = makeViewModel()
        await waitUntil("the initial free state to load") {
            !fixture.vm.state.isLoading && fixture.vm.state.premiumStatus == .free
        }
        #expect(fixture.vm.state.premiumStatus == .free)

        fixture.premium.setValue(.gracePeriod)
        await waitUntil("the grace-period state to propagate") {
            fixture.vm.state.premiumStatus == .gracePeriod
        }

        #expect(fixture.vm.state.premiumStatus == .gracePeriod)
    }

    /// `MoreViewModelTest.kt:359-370`.
    @Test("a free user tapping premium opens the paywall from the settings source")
    func aFreeUserTappingPremiumOpensThePaywallFromTheSettingsSource() async {
        let fixture = makeViewModel()
        await waitUntil("the initial state to load") { !fixture.vm.state.isLoading }

        fixture.vm.onEvent(.premiumClicked)
        await waitUntil("the paywall to open from settings") { fixture.paywall.request != nil }

        #expect(fixture.paywall.request?.source == .settings)
        #expect(fixture.vm.pendingEffects.isEmpty)
    }

    /// `MoreViewModelTest.kt:377-392`.
    @Test("an entitled user tapping premium is sent to subscription management")
    func anEntitledUserTappingPremiumIsSentToSubscriptionManagement() async {
        let fixture = makeViewModel(premiumStatus: .premium)
        await waitUntil("the entitled state to load") {
            !fixture.vm.state.isLoading && fixture.vm.state.premiumStatus == .premium
        }

        fixture.vm.onEvent(.premiumClicked)
        await waitUntil("the subscription-management effect") { !fixture.vm.pendingEffects.isEmpty }

        let effects = fixture.vm.consumeEffects()
        #expect(effects == [.openUrl("https://apps.apple.com/account/subscriptions")])
        // The paywall must not open.
        #expect(fixture.paywall.request == nil)
    }

    /// In-app review spec §4 — the row is a store link, never the StoreKit sheet.
    @Test("tapping rate us opens the App Store write-review page")
    func tappingRateUsOpensTheWriteReviewPage() {
        let fixture = makeViewModel(premiumStatus: .free)

        fixture.vm.onEvent(.rateUsClicked)

        #expect(fixture.vm.consumeEffects() == [.openUrl(MoreViewModel.appStoreWriteReviewUrl)])
        #expect(MoreViewModel.appStoreWriteReviewUrl == "https://apps.apple.com/app/id6807102436?action=write-review")
        #expect(fixture.paywall.request == nil)
    }

    /// `MoreViewModelTest.kt:396-408`.
    @Test("a grace period user tapping premium is sent to subscription management")
    func aGracePeriodUserTappingPremiumIsSentToSubscriptionManagement() async {
        let fixture = makeViewModel(premiumStatus: .gracePeriod)
        await waitUntil("the entitled state to load") {
            !fixture.vm.state.isLoading && fixture.vm.state.premiumStatus == .gracePeriod
        }

        fixture.vm.onEvent(.premiumClicked)
        await waitUntil("the subscription-management effect") { !fixture.vm.pendingEffects.isEmpty }

        let effects = fixture.vm.consumeEffects()
        #expect(effects.count == 1)
        if case .openUrl = effects.first {
        } else {
            Issue.record("expected an openUrl effect, got \(String(describing: effects.first))")
        }
        #expect(fixture.paywall.request == nil)
    }

    // MARK: - Doctor report

    /// `MoreViewModelTest.kt:415-428`.
    @Test("a free user tapping the doctor report gets the paywall and never the screen")
    func aFreeUserTappingTheDoctorReportGetsThePaywallAndNeverTheScreen() async {
        let fixture = makeViewModel()
        await waitUntil("the initial state to load") { !fixture.vm.state.isLoading }

        fixture.vm.onEvent(.doctorReportClicked)
        await waitUntil("the paywall to open from doctorReport") { fixture.paywall.request != nil }

        #expect(fixture.paywall.request?.source == .doctorReport)
        #expect(fixture.vm.pendingEffects.isEmpty)
    }

    /// `MoreViewModelTest.kt:431-443`.
    @Test("an entitled user tapping the doctor report opens it")
    func anEntitledUserTappingTheDoctorReportOpensIt() async {
        let fixture = makeViewModel(premiumStatus: .premium)
        await waitUntil("the entitled state to load") {
            !fixture.vm.state.isLoading && fixture.vm.state.premiumStatus == .premium
        }

        fixture.vm.onEvent(.doctorReportClicked)
        await waitUntil("the openDoctorReport effect") { !fixture.vm.pendingEffects.isEmpty }

        let effects = fixture.vm.consumeEffects()
        #expect(effects == [.openDoctorReport])
        #expect(fixture.paywall.request == nil)
    }

    /// `MoreViewModelTest.kt:446-457`.
    @Test("a grace period user reaches the doctor report")
    func aGracePeriodUserReachesTheDoctorReport() async {
        let fixture = makeViewModel(premiumStatus: .gracePeriod)
        await waitUntil("the entitled state to load") {
            !fixture.vm.state.isLoading && fixture.vm.state.premiumStatus == .gracePeriod
        }

        fixture.vm.onEvent(.doctorReportClicked)
        await waitUntil("the openDoctorReport effect") { !fixture.vm.pendingEffects.isEmpty }

        let effects = fixture.vm.consumeEffects()
        #expect(effects == [.openDoctorReport])
    }
}
