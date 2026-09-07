// Ported 1:1 from
// `feature/settings/src/main/kotlin/com/alicansekban/salus/feature/settings/ui/about/AboutUiState.kt`.

import SalusPremium

/// The About screen's state (`AboutUiState.kt:16-23`).
///
/// [appUserID] is the RevenueCat `appUserID` a developer pastes into the RevenueCat dashboard to
/// grant a gift subscription; it is `nil` when the store SDK is not configured (e.g. a debug build
/// without an API key), in which case the support card hides the id line and the copy button.
///
/// The id line and copy button are hidden until [idRevealed]: five consecutive taps on the app-name
/// headline (each within 3 s of the previous) reveal them for the ViewModel's lifetime. Nothing is
/// persisted — the reveal is session-only.
public struct AboutUiState: Sendable, Equatable {
    public var appUserID: String?
    public var premiumStatus: PremiumStatus
    /// True once the 5-tap reveal gesture has been completed; stays true for the session.
    public var idRevealed: Bool
    /// True briefly after the support code is copied, so the button can say "Copied".
    public var copied: Bool

    public init(
        appUserID: String? = nil,
        premiumStatus: PremiumStatus = .free,
        idRevealed: Bool = false,
        copied: Bool = false
    ) {
        self.appUserID = appUserID
        self.premiumStatus = premiumStatus
        self.idRevealed = idRevealed
        self.copied = copied
    }
}

/// User intents (`AboutUiState.kt:25-31`).
public enum AboutEvent: Sendable, Equatable {
    /// A tap on the app-name headline; five consecutive taps reveal the support code.
    case appNameTapped
    /// The user tapped the copy button; the screen copies the id and this flips `AboutUiState.copied`.
    case copySupportCode
}
