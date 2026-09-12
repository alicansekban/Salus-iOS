// Ported 1:1 from `feature/settings/src/test/kotlin/com/alicansekban/salus/feature/settings/
// ui/more/MoreViewModelTest.kt` — the "Premium colour themes" region (`MoreViewModelTest.kt:463-548`).
//
// Split out of `MoreViewModelTests.swift` in M16 Task 10 so that suite stays under the 500-line
// `file_length` gate: the M15 sheet model added five cases here, and the parent suite holds the
// cycle / settings / premium / doctor-report regions. The helpers (`makeViewModel`, the fakes) are
// `MoreViewModelTests`'s; only the `aFreeUsersPickOfTheClassicPaletteIsAppliedWithoutThePaywall`
// and `aFreeUsersPickOfALockedPaletteOpensThePaywallAndIsNotPersisted` cases are truly new — the
// rest were renamed by the sheet migration (the palette now applies under the sheet, which stays
// open).

import Foundation
import SalusModel
import SalusPremium
import Testing

@testable import FeatureSettings

@Suite("MoreViewModel colour themes")
@MainActor
struct MorePremiumThemeTests {
    private func makeViewModel(
        premiumStatus: PremiumStatus = .free,
        preferences: FakeSettingsPreferences = FakeSettingsPreferences(),
        premium: FakePremiumRepository? = nil,
        paywall: PaywallController = PaywallController()
    ) -> (
        vm: MoreViewModel,
        premium: FakePremiumRepository,
        preferences: FakeSettingsPreferences,
        paywall: PaywallController
    ) {
        let premiumRepository = premium ?? FakePremiumRepository(value: premiumStatus)
        let vm = MoreViewModel(
            profileRepository: FakeProfileRepository(),
            premiumRepository: premiumRepository,
            preferences: preferences,
            localeController: FakeAppLocaleController(),
            paywallController: paywall
        )
        return (vm, premiumRepository, preferences, paywall)
    }

    /// `MoreViewModelTest.kt:464-472`.
    @Test("state carries the stored colour theme")
    func stateCarriesTheStoredColourTheme() async {
        let preferences = FakeSettingsPreferences(premiumTheme: .sunset)
        let fixture = makeViewModel(preferences: preferences)

        await waitUntil("the stored colour theme to load") {
            !fixture.vm.state.isLoading && fixture.vm.state.premiumTheme == .sunset
        }

        #expect(fixture.vm.state.premiumTheme == .sunset)
    }

    /// `MoreViewModelTest.kt:475-490` — the palette applies live behind the sheet; the user stays
    /// where they are.
    @Test("a premium user's colour theme is persisted and the sheet stays open")
    func aPremiumUsersColourThemeIsPersistedAndTheSheetStaysOpen() async {
        let fixture = makeViewModel(premiumStatus: .premium)
        await waitUntil("the entitled state to load") {
            !fixture.vm.state.isLoading && fixture.vm.state.premiumStatus == .premium
        }

        fixture.vm.onEvent(.themeSheetOpened)
        await waitUntil("the theme sheet to open") { fixture.vm.state.isThemeSheetOpen }

        fixture.vm.onEvent(.colorThemeSelected(.ocean))
        await waitUntil("the colour theme to persist and reach state") {
            fixture.preferences.premiumThemeValueSync == .ocean && fixture.vm.state.premiumTheme == .ocean
        }

        #expect(fixture.preferences.premiumThemeValueSync == .ocean)
        #expect(fixture.vm.state.premiumTheme == .ocean)
        #expect(fixture.vm.state.isThemeSheetOpen)
        #expect(fixture.paywall.request == nil)
    }

    /// `MoreViewModelTest.kt:493-503`.
    @Test("a grace period user may still change the colour theme")
    func aGracePeriodUserMayStillChangeTheColourTheme() async {
        let fixture = makeViewModel(premiumStatus: .gracePeriod)
        await waitUntil("the entitled state to load") {
            !fixture.vm.state.isLoading && fixture.vm.state.premiumStatus == .gracePeriod
        }

        fixture.vm.onEvent(.colorThemeSelected(.forest))
        await waitUntil("the colour theme to persist") {
            fixture.preferences.premiumThemeValueSync == .forest
        }

        #expect(fixture.preferences.premiumThemeValueSync == .forest)
        #expect(fixture.paywall.request == nil)
    }

    /// `MoreViewModelTest.kt:511-526` — the locked rows in the sheet are tappable on purpose: the
    /// tap is what sells the subscription. It must open the paywall, leave the stored palette
    /// alone, and take the sheet away — the paywall is a sheet of its own and would otherwise open
    /// behind it.
    @Test("a free user's pick of a locked palette opens the paywall and is not persisted")
    func aFreeUsersPickOfALockedPaletteOpensThePaywallAndIsNotPersisted() async {
        let fixture = makeViewModel()
        await waitUntil("the initial state to load") { !fixture.vm.state.isLoading }

        fixture.vm.onEvent(.themeSheetOpened)
        await waitUntil("the theme sheet to open") { fixture.vm.state.isThemeSheetOpen }
        #expect(fixture.vm.state.isThemeSheetOpen)

        // Ocean stands for all three locked palettes; they share the one branch.
        fixture.vm.onEvent(.colorThemeSelected(.ocean))
        await waitUntil("the paywall to open from themes and the sheet to close") {
            fixture.paywall.request?.source == .themes && !fixture.vm.state.isThemeSheetOpen
        }

        #expect(fixture.paywall.request?.source == .themes)
        #expect(fixture.preferences.premiumThemeValueSync == .classic)
        #expect(fixture.vm.state.premiumTheme == .classic)
        #expect(fixture.vm.state.isThemeSheetOpen == false)
    }

    /// `MoreViewModelTest.kt:534-548` — Classic is the free palette and the sheet never draws a
    /// lock on it, so picking it has to be a plain selection — including for the lapsed subscriber
    /// whose stored palette is a premium one and who is reaching for the way back (A60).
    @Test("a free user's pick of the classic palette is applied without the paywall")
    func aFreeUsersPickOfTheClassicPaletteIsAppliedWithoutThePaywall() async {
        let preferences = FakeSettingsPreferences(premiumTheme: .ocean)
        let fixture = makeViewModel(preferences: preferences)
        await waitUntil("the initial state to load") { !fixture.vm.state.isLoading }

        fixture.vm.onEvent(.themeSheetOpened)
        await waitUntil("the theme sheet to open") { fixture.vm.state.isThemeSheetOpen }

        fixture.vm.onEvent(.colorThemeSelected(.classic))
        await waitUntil("the colour theme to persist and reach state") {
            fixture.preferences.premiumThemeValueSync == .classic && fixture.vm.state.premiumTheme == .classic
        }

        #expect(fixture.preferences.premiumThemeValueSync == .classic)
        #expect(fixture.vm.state.premiumTheme == .classic)
        #expect(fixture.paywall.request == nil)
        #expect(fixture.vm.state.isThemeSheetOpen)
    }
}
