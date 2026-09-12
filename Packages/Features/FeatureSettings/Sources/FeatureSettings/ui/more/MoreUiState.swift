// Ported 1:1 from
// `feature/settings/src/main/kotlin/com/alicansekban/salus/feature/settings/ui/more/MoreUiState.kt`
// in its M15 shape.
//
// The three UDF types keep their Kotlin names and their Kotlin job. Two divergences are recorded in
// `MoreViewModel.swift`'s header (`appStoreSubscriptionsUrl`, the buffered-effects queue); the
// state itself follows the M15 twin exactly — the theme and language sheets are two `Bool` flags on
// the state, driven by their own open/dismiss events, replacing the M14 era single
// `activeDialog: MoreDialog?`.

import SalusModel
import SalusPremium

/// The More tab is the app's settings hub: the four data tabs cover everything else, so splitting a
/// near-empty "More" list from a separate Settings screen only added a hop
/// (`MoreUiState.kt:15-40`).
public struct MoreUiState: Sendable, Equatable {
    public var isLoading: Bool
    /// The stored display name; blank when onboarding skipped it, which the row points out.
    public var profileName: String
    /// Chipped next to the name on the profile card; nil while it has never been answered.
    public var profileSex: Sex?
    /// Cycle tracking is hidden for male profiles; see docs/architecture/m9-plan.md item 1.
    public var showCycle: Bool
    public var themeMode: ThemeMode
    /// The stored selection, which is what the picker shows — free users see their pick too.
    public var premiumTheme: PremiumTheme
    public var language: AppLanguage
    /// The real three-state entitlement (`PremiumStatus.kt`): `free`/`premium`/`gracePeriod`, where
    /// `gracePeriod` is still entitled. The gate reads `isEntitled`.
    public var premiumStatus: PremiumStatus
    public var appLockEnabled: Bool
    public var secureScreenEnabled: Bool
    /// The appearance sheet — opened by both the mode row and the palette row. It outlives a
    /// selection on purpose: mode and palette live in the same sheet (`MoreUiState.kt:33-37`).
    public var isThemeSheetOpen: Bool
    /// The language sheet — behaves exactly like the appearance sheet: the pick applies live and
    /// the sheet stays open (`MoreUiState.kt:42-47`).
    public var isLanguageSheetOpen: Bool

    public init(
        isLoading: Bool = true,
        profileName: String = "",
        profileSex: Sex? = nil,
        showCycle: Bool = false,
        themeMode: ThemeMode = .system,
        premiumTheme: PremiumTheme = .classic,
        language: AppLanguage = .system,
        premiumStatus: PremiumStatus = .free,
        appLockEnabled: Bool = false,
        secureScreenEnabled: Bool = false,
        isThemeSheetOpen: Bool = false,
        isLanguageSheetOpen: Bool = false
    ) {
        self.isLoading = isLoading
        self.profileName = profileName
        self.profileSex = profileSex
        self.showCycle = showCycle
        self.themeMode = themeMode
        self.premiumTheme = premiumTheme
        self.language = language
        self.premiumStatus = premiumStatus
        self.appLockEnabled = appLockEnabled
        self.secureScreenEnabled = secureScreenEnabled
        self.isThemeSheetOpen = isThemeSheetOpen
        self.isLanguageSheetOpen = isLanguageSheetOpen
    }
}

/// User intents (`MoreUiState.kt:50-86`).
public enum MoreEvent: Sendable, Equatable {
    /// Either appearance row was tapped; both open the one theme sheet.
    case themeSheetOpened
    /// The sheet was swiped away, closed or dismissed by its scrim. Nothing is written.
    case themeSheetDismissed
    case selectTheme(ThemeMode)
    /// A colour picked in the theme sheet's palette list. Free users may open the sheet and tap a
    /// locked row; the entitlement check lives in the ViewModel, not in the screen.
    case colorThemeSelected(PremiumTheme)
    /// The "app language" row was tapped.
    case languageSheetOpened
    /// The language sheet was swiped away, closed or dismissed by its scrim.
    case languageSheetDismissed
    /// A language picked in the language sheet. Applied immediately and the sheet stays open.
    case selectLanguage(AppLanguage)
    /// Sent only after a successful authentication when enabling.
    case setAppLock(Bool)
    case setSecureScreen(Bool)
    /// The premium row. A free user gets the paywall; an entitled one gets the store's own
    /// subscription management, because there is nothing left to sell them.
    case premiumClicked
    /// The doctor report row. Gated in the ViewModel like the premium palettes are: a free user
    /// gets the paywall and never reaches the screen, because the report is premium in full.
    case doctorReportClicked
    /// The trends row. Deliberately **not** gated, unlike `doctorReportClicked`: the trends screen
    /// shows its own lock, so a free user is taken there and can see what a subscription buys
    /// instead of being bounced straight into the paywall.
    case trendsClicked
    /// The "Rate Salus" row (in-app review spec §4). Always the store's write-review page, never
    /// the StoreKit sheet: Apple rejects `requestReview` behind a button, and the sheet is the
    /// Home trigger's alone.
    case rateUsClicked
}

/// The one-shot outcomes the screen has to carry out, because only it can reach the system
/// (`MoreUiState.kt:76-99`).
public enum MoreEffect: Sendable, Equatable {
    /// Opened with `UIApplication.open(_:)`, the same way the screen reaches any system destination.
    case openUrl(String)
    /// Push the doctor report screen. An effect rather than a direct navigation call, because the
    /// key belongs to `FeatureAIHealth` and features cannot see each other's navigation keys — the
    /// shell wires it, the same way it wires Cycle. It stays a ViewModel decision because the
    /// entitlement check that precedes it is one.
    case openDoctorReport
    /// Push the trends screen. An effect for the same reason `openDoctorReport` is one: the key
    /// belongs to `FeatureTrends` and features cannot see each other's navigation keys, so the
    /// shell wires it. Unlike the report there is no entitlement check in front of it — the screen
    /// carries its own lock.
    case openTrends
}
