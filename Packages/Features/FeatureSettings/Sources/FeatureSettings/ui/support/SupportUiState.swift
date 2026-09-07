// Ported 1:1 from
// `feature/settings/src/main/kotlin/com/alicansekban/salus/feature/settings/ui/support/SupportUiState.kt`.

import SalusPremium

/// The Support screen's state (`SupportUiState.kt:16-23`).
///
/// [appUserID] is the RevenueCat `appUserID` a developer pastes into the RevenueCat dashboard to
/// grant a gift subscription; it is `nil` when the store SDK is not configured (e.g. a debug build
/// without an API key), in which case the support card hides the id line and the copy button.
///
/// The id line and copy button are hidden until [idRevealed]: five consecutive taps on the screen
/// title (each within 3 s of the previous) reveal them for the ViewModel's lifetime. Nothing is
/// persisted — the reveal is session-only.
public struct SupportUiState: Sendable, Equatable {
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

/// User intents (`SupportUiState.kt:25-31`).
public enum SupportEvent: Sendable, Equatable {
    /// A tap on the screen title; five consecutive taps reveal the support code.
    case titleTapped
    /// The user tapped the copy button; the screen copies the id and this flips `SupportUiState.copied`.
    case copySupportCode
}
