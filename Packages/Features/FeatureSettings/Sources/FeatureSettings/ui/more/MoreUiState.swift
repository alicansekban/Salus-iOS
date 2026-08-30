// Ported 1:1 from
// `feature/settings/src/main/kotlin/com/alicansekban/salus/feature/settings/ui/more/MoreUiState.kt`.
//
// The three UDF types keep their Kotlin names and their Kotlin job. Two divergences are visible in
// the types themselves, both recorded in `MoreViewModel.swift`'s header and restated here so a
// reader of the state alone sees them:
//
//   * `premiumStatus` is `MorePremiumStatusValue` (`.free`/`.entitled`), not Kotlin's three-state
//     `PremiumStatus` — recorded divergence (1). The `.entitled` case folds Android's
//     `GRACE_PERIOD` and `PREMIUM` into one; the gate that branched on `isEntitled` reads
//     `== .entitled`. See `MorePremiumStatus.swift` for why the boundary collapses there.
//   * The `MoreEffect` cases carry the same names as the Kotlin sealed interface; only the URL they
//     hand the screen is platform-mapped — recorded divergence (3), `appStoreSubscriptionsUrl` in
//     `MoreViewModel.swift`.

import SalusModel

/// Which selection popup is open (`MoreUiState.kt:9-13`).
public enum MoreDialog: Sendable, Equatable {
    case theme
    case colorTheme
    case language
}

/// The More tab is the app's settings hub: the four data tabs cover everything else, so splitting a
/// near-empty "More" list from a separate Settings screen only added a hop
/// (`MoreUiState.kt:15-33`).
public struct MoreUiState: Sendable, Equatable {
    public var isLoading: Bool
    /// The stored display name; blank when onboarding skipped it, which the row points out.
    public var profileName: String
    /// Cycle tracking is hidden for male profiles; see docs/architecture/m9-plan.md item 1.
    public var showCycle: Bool
    public var themeMode: ThemeMode
    /// The stored selection, which is what the picker shows — free users see their pick too.
    public var premiumTheme: PremiumTheme
    public var language: AppLanguage
    /// Two-state (ruling 5 / divergence 1): `.entitled` folds Android's `GRACE_PERIOD` and
    /// `PREMIUM`. The gate reads `== .entitled`.
    public var premiumStatus: MorePremiumStatusValue
    public var appLockEnabled: Bool
    public var secureScreenEnabled: Bool
    public var activeDialog: MoreDialog?

    public init(
        isLoading: Bool = true,
        profileName: String = "",
        showCycle: Bool = false,
        themeMode: ThemeMode = .system,
        premiumTheme: PremiumTheme = .classic,
        language: AppLanguage = .system,
        premiumStatus: MorePremiumStatusValue = .free,
        appLockEnabled: Bool = false,
        secureScreenEnabled: Bool = false,
        activeDialog: MoreDialog? = nil
    ) {
        self.isLoading = isLoading
        self.profileName = profileName
        self.showCycle = showCycle
        self.themeMode = themeMode
        self.premiumTheme = premiumTheme
        self.language = language
        self.premiumStatus = premiumStatus
        self.appLockEnabled = appLockEnabled
        self.secureScreenEnabled = secureScreenEnabled
        self.activeDialog = activeDialog
    }
}

/// User intents (`MoreUiState.kt:35-73`).
public enum MoreEvent: Sendable, Equatable {
    case dialogRequested(MoreDialog)
    case dialogDismissed
    case selectTheme(ThemeMode)
    /// A colour picked in the premium palette dialog. Free users may open the dialog and tap an
    /// option; the entitlement check lives in the ViewModel, not in the screen.
    case colorThemeSelected(PremiumTheme)
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
