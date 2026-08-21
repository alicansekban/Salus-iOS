import SalusModel
import SwiftUI

// The half of the theme vocabulary that needs a framework or the token layer, and therefore
// cannot live in `SalusModel` (which links no UI framework, mirroring Android `:core:model`).
//
// `ThemeMode` and `PremiumTheme` themselves — raw values, storage keys, defaults, decoding and
// `isDark(systemIsDark:)` — are pure domain and live in `SalusModel/ThemeSettings.swift`.

extension ThemeMode {
    /// The value to hand SwiftUI's `.preferredColorScheme`: `nil` for `SYSTEM`, so the OS keeps
    /// deciding — the iOS shape of `isSystemInDarkTheme()` being the Android default
    /// (`Theme.kt:87`).
    public var preferredColorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

extension PremiumTheme {
    /// The eight accent roles this palette paints, in the given theme (§4).
    ///
    /// `classic` returns the brand accents, which is why applying it is a no-op.
    public func accentPalette(dark: Bool) -> SalusPremiumAccentPalette {
        switch self {
        case .classic: dark ? SalusPremiumAccents.classicDark : SalusPremiumAccents.classicLight
        case .ocean: dark ? SalusPremiumAccents.oceanDark : SalusPremiumAccents.oceanLight
        case .sunset: dark ? SalusPremiumAccents.sunsetDark : SalusPremiumAccents.sunsetLight
        case .forest: dark ? SalusPremiumAccents.forestDark : SalusPremiumAccents.forestLight
        }
    }
}
