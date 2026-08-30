// Ported 1:1 from
// `feature/settings/src/test/kotlin/com/alicansekban/salus/feature/settings/ui/more/
// MoreViewModelTest.kt`.
//
// The 20 cases port by name, grouped exactly as the Kotlin test groups them (cycle visibility 4,
// settings 5, premium 4, doctor report 3, colour themes 4). Turbine's `state.test { awaitItem() }`
// becomes reading `viewModel.state` after `waitUntil`, and its `effects.test { awaitItem() }`
// becomes reading `pendingEffects` / `consumeEffects()` — the same substitution the M7
// `ReminderHealthViewModelTests` made for `@Observable`, generalised to the buffered array.
//
// The `MainDispatcherRule` + `runTest` virtual scheduler becomes the cooperative pool: each
// `advanceUntilIdle()` is a `waitUntil` that yields the main actor until the named condition holds.
// `hotViewModel()` — a ViewModel with a live `state` subscriber — is spelled the same way, because
// `@Observable`'s observation starts in `init` rather than on first read, so every ViewModel is
// already "hot".

import Foundation
import SalusModel
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
    /// them (`MoreViewModelTest.kt:103-110`).
    private func makeViewModel(
        profile: Profile? = nil,
        premiumStatus: MorePremiumStatusValue = .free,
        preferences: FakeSettingsPreferences = FakeSettingsPreferences(),
        locale: FakeAppLocaleController = FakeAppLocaleController(),
        profileRepository: FakeProfileRepository? = nil,
        premium: FakeMorePremiumStatus? = nil,
        paywall: FakePaywallRequester = FakePaywallRequester()
    ) -> (
        vm: MoreViewModel,
        repository: FakeProfileRepository,
        premium: FakeMorePremiumStatus,
        preferences: FakeSettingsPreferences,
        locale: FakeAppLocaleController,
        paywall: FakePaywallRequester
    ) {
        let repository = profileRepository ?? FakeProfileRepository(profile: profile)
        let premiumStatusFake = premium ?? FakeMorePremiumStatus(value: premiumStatus)
        let vm = MoreViewModel(
            profileRepository: repository,
            premiumStatus: premiumStatusFake,
            preferences: preferences,
            localeController: locale,
            paywallRequester: paywall
        )
        return (vm, repository, premiumStatusFake, preferences, locale, paywall)
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

    /// `MoreViewModelTest.kt:179-195`.
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

    /// `MoreViewModelTest.kt:197-210`.
    @Test("selecting a theme persists it and closes the dialog")
    func selectingAThemePersistsItAndClosesTheDialog() async {
        let fixture = makeViewModel()
        await waitUntil("the initial state to load") { !fixture.vm.state.isLoading }

        fixture.vm.onEvent(.dialogRequested(.theme))
        await waitUntil("the theme dialog to open") { fixture.vm.state.activeDialog == .theme }
        #expect(fixture.vm.state.activeDialog == .theme)

        fixture.vm.onEvent(.selectTheme(.dark))
        await waitUntil("the theme to persist and the dialog to close") {
            fixture.preferences.themeModeValueSync == .dark && fixture.vm.state.activeDialog == nil
        }

        #expect(fixture.preferences.themeModeValueSync == .dark)
        #expect(fixture.vm.state.activeDialog == nil)
    }

    /// `MoreViewModelTest.kt:212-225`.
    @Test("selecting a language applies the locale and closes the dialog")
    func selectingALanguageAppliesTheLocaleAndClosesTheDialog() async {
        let fixture = makeViewModel()
        await waitUntil("the initial state to load") { !fixture.vm.state.isLoading }

        fixture.vm.onEvent(.dialogRequested(.language))
        await waitUntil("the language dialog to open") { fixture.vm.state.activeDialog == .language }

        fixture.vm.onEvent(.selectLanguage(.turkish))
        await waitUntil("the locale to apply and the dialog to close") {
            fixture.locale.currentSync == .turkish && fixture.vm.state.activeDialog == nil
        }

        #expect(fixture.locale.currentSync == .turkish)
        #expect(fixture.locale.appliedSync == [.turkish])
        #expect(fixture.vm.state.activeDialog == nil)
    }

    /// `MoreViewModelTest.kt:227-239`.
    @Test("dismissing a dialog leaves the setting untouched")
    func dismissingADialogLeavesTheSettingUntouched() async {
        let fixture = makeViewModel()
        await waitUntil("the initial state to load") { !fixture.vm.state.isLoading }

        fixture.vm.onEvent(.dialogRequested(.theme))
        await waitUntil("the theme dialog to open") { fixture.vm.state.activeDialog == .theme }

        fixture.vm.onEvent(.dialogDismissed)
        await waitUntil("the dialog to close") { fixture.vm.state.activeDialog == nil }

        #expect(fixture.vm.state.activeDialog == nil)
        #expect(fixture.preferences.themeModeValueSync == .system)
    }

    /// `MoreViewModelTest.kt:241-252`.
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

    /// `MoreViewModelTest.kt:258-268`.
    @Test("state follows the entitlement")
    func stateFollowsTheEntitlement() async {
        let fixture = makeViewModel()
        await waitUntil("the initial free state to load") {
            !fixture.vm.state.isLoading && fixture.vm.state.premiumStatus == .free
        }
        #expect(fixture.vm.state.premiumStatus == .free)

        // The Kotlin flips `premium.status.value = PremiumStatus.GRACE_PERIOD`; the iOS fake flips
        // to `.entitled` (divergence 1 — grace is folded).
        fixture.premium.setValue(.entitled)
        await waitUntil("the entitled state to propagate") {
            fixture.vm.state.premiumStatus == .entitled
        }

        #expect(fixture.vm.state.premiumStatus == .entitled)
    }

    /// `MoreViewModelTest.kt:270-282`.
    @Test("a free user tapping premium opens the paywall from the settings source")
    func aFreeUserTappingPremiumOpensThePaywallFromTheSettingsSource() async {
        let fixture = makeViewModel()
        await waitUntil("the initial state to load") { !fixture.vm.state.isLoading }

        fixture.vm.onEvent(.premiumClicked)
        await waitUntil("the paywall to open from settings") { fixture.paywall.last != nil }

        #expect(fixture.paywall.last == .settings)
        #expect(fixture.vm.pendingEffects.isEmpty)
    }

    /// `MoreViewModelTest.kt:288-304`.
    @Test("an entitled user tapping premium is sent to subscription management")
    func anEntitledUserTappingPremiumIsSentToSubscriptionManagement() async {
        let fixture = makeViewModel(premiumStatus: .entitled)
        await waitUntil("the entitled state to load") {
            !fixture.vm.state.isLoading && fixture.vm.state.premiumStatus == .entitled
        }

        fixture.vm.onEvent(.premiumClicked)
        await waitUntil("the subscription-management effect") { !fixture.vm.pendingEffects.isEmpty }

        let effects = fixture.vm.consumeEffects()
        #expect(effects == [.openUrl("https://apps.apple.com/account/subscriptions")])
        // The paywall must not open — divergence (2): `PaywallRequester` is the stand-in, but the
        // gate routing is the same.
        #expect(fixture.paywall.last == nil)
    }

    /// `MoreViewModelTest.kt:306-320`. The grace period is folded into `.entitled` (divergence 1).
    @Test("a grace period user tapping premium is sent to subscription management")
    func aGracePeriodUserTappingPremiumIsSentToSubscriptionManagement() async {
        let fixture = makeViewModel(premiumStatus: .entitled)
        await waitUntil("the entitled state to load") {
            !fixture.vm.state.isLoading && fixture.vm.state.premiumStatus == .entitled
        }

        fixture.vm.onEvent(.premiumClicked)
        await waitUntil("the subscription-management effect") { !fixture.vm.pendingEffects.isEmpty }

        let effects = fixture.vm.consumeEffects()
        #expect(effects.count == 1)
        if case .openUrl = effects.first {
        } else {
            Issue.record("expected an openUrl effect, got \(String(describing: effects.first))")
        }
        #expect(fixture.paywall.last == nil)
    }

    // MARK: - Doctor report

    /// `MoreViewModelTest.kt:326-340`.
    @Test("a free user tapping the doctor report gets the paywall and never the screen")
    func aFreeUserTappingTheDoctorReportGetsThePaywallAndNeverTheScreen() async {
        let fixture = makeViewModel()
        await waitUntil("the initial state to load") { !fixture.vm.state.isLoading }

        fixture.vm.onEvent(.doctorReportClicked)
        await waitUntil("the paywall to open from doctorReport") { fixture.paywall.last != nil }

        #expect(fixture.paywall.last == .doctorReport)
        #expect(fixture.vm.pendingEffects.isEmpty)
    }

    /// `MoreViewModelTest.kt:342-355`.
    @Test("an entitled user tapping the doctor report opens it")
    func anEntitledUserTappingTheDoctorReportOpensIt() async {
        let fixture = makeViewModel(premiumStatus: .entitled)
        await waitUntil("the entitled state to load") {
            !fixture.vm.state.isLoading && fixture.vm.state.premiumStatus == .entitled
        }

        fixture.vm.onEvent(.doctorReportClicked)
        await waitUntil("the openDoctorReport effect") { !fixture.vm.pendingEffects.isEmpty }

        let effects = fixture.vm.consumeEffects()
        #expect(effects == [.openDoctorReport])
        #expect(fixture.paywall.last == nil)
    }

    /// `MoreViewModelTest.kt:357-369`. The grace period is folded into `.entitled` (divergence 1).
    @Test("a grace period user reaches the doctor report")
    func aGracePeriodUserReachesTheDoctorReport() async {
        let fixture = makeViewModel(premiumStatus: .entitled)
        await waitUntil("the entitled state to load") {
            !fixture.vm.state.isLoading && fixture.vm.state.premiumStatus == .entitled
        }

        fixture.vm.onEvent(.doctorReportClicked)
        await waitUntil("the openDoctorReport effect") { !fixture.vm.pendingEffects.isEmpty }

        let effects = fixture.vm.consumeEffects()
        #expect(effects == [.openDoctorReport])
    }

    // MARK: - Premium colour themes

    /// `MoreViewModelTest.kt:375-384`.
    @Test("state carries the stored colour theme")
    func stateCarriesTheStoredColourTheme() async {
        let preferences = FakeSettingsPreferences(premiumTheme: .sunset)
        let fixture = makeViewModel(preferences: preferences)

        await waitUntil("the stored colour theme to load") {
            !fixture.vm.state.isLoading && fixture.vm.state.premiumTheme == .sunset
        }

        #expect(fixture.vm.state.premiumTheme == .sunset)
    }

    /// `MoreViewModelTest.kt:386-401`.
    @Test("a premium user's colour theme is persisted and the dialog closes")
    func aPremiumUsersColourThemeIsPersistedAndTheDialogCloses() async {
        let fixture = makeViewModel(premiumStatus: .entitled)
        await waitUntil("the entitled state to load") {
            !fixture.vm.state.isLoading && fixture.vm.state.premiumStatus == .entitled
        }

        fixture.vm.onEvent(.dialogRequested(.colorTheme))
        await waitUntil("the colorTheme dialog to open") {
            fixture.vm.state.activeDialog == .colorTheme
        }

        fixture.vm.onEvent(.colorThemeSelected(.ocean))
        await waitUntil("the colour theme to persist and the dialog to close") {
            fixture.preferences.premiumThemeValueSync == .ocean && fixture.vm.state.activeDialog == nil
        }

        #expect(fixture.preferences.premiumThemeValueSync == .ocean)
        #expect(fixture.vm.state.premiumTheme == .ocean)
        #expect(fixture.vm.state.activeDialog == nil)
        #expect(fixture.paywall.last == nil)
    }

    /// `MoreViewModelTest.kt:403-414`. The grace period is folded into `.entitled` (divergence 1).
    @Test("a grace period user may still change the colour theme")
    func aGracePeriodUserMayStillChangeTheColourTheme() async {
        let fixture = makeViewModel(premiumStatus: .entitled)
        await waitUntil("the entitled state to load") {
            !fixture.vm.state.isLoading && fixture.vm.state.premiumStatus == .entitled
        }

        fixture.vm.onEvent(.colorThemeSelected(.forest))
        await waitUntil("the colour theme to persist") {
            fixture.preferences.premiumThemeValueSync == .forest
        }

        #expect(fixture.preferences.premiumThemeValueSync == .forest)
        #expect(fixture.paywall.last == nil)
    }

    /// `MoreViewModelTest.kt:416-431`.
    @Test("a free user's pick opens the paywall and is not persisted")
    func aFreeUsersPickOpensThePaywallAndIsNotPersisted() async {
        let fixture = makeViewModel()
        await waitUntil("the initial state to load") { !fixture.vm.state.isLoading }

        fixture.vm.onEvent(.dialogRequested(.colorTheme))
        await waitUntil("the colorTheme dialog to open") {
            fixture.vm.state.activeDialog == .colorTheme
        }
        #expect(fixture.vm.state.activeDialog == .colorTheme)

        fixture.vm.onEvent(.colorThemeSelected(.forest))
        await waitUntil("the paywall to open from themes and the dialog to close") {
            fixture.paywall.last == .themes && fixture.vm.state.activeDialog == nil
        }

        #expect(fixture.paywall.last == .themes)
        #expect(fixture.preferences.premiumThemeValueSync == .classic)
        #expect(fixture.vm.state.premiumTheme == .classic)
        #expect(fixture.vm.state.activeDialog == nil)
    }
}
