// The app target's own String Catalog, and the first one it has ever had.
//
// Every other catalog in the tree belongs to a package and is read through `Bundle.module`
// (`VitalsStrings.swift` is the shape). The shell has no module bundle — its resources are the
// main bundle's — so this enum is the same typed accessor over `Bundle.main`, and the reason it
// exists is the same: a bare `String(localized:)` at a call site names its key inline, where a
// typo ships the key as the label instead of failing to compile.
//
// WHY THE COPY LIVES HERE AND NOT IN `FeatureSettings`. The two keys below are Android's
// `feature/settings` strings (`MoreScreen.kt:222-231`), and on Android the More list is that
// module's screen. On iOS the More list is still `PlaceholderScreen` — the settings hub is M8 —
// so the only thing that draws these two sentences today is the shell. Copying them into the
// shell's own catalog keeps the port honest about that: when M8 lands the settings hub, the row
// moves into `FeatureSettings` with the rest of `MoreScreen`, and this file and its catalog are
// deleted along with `PlaceholderScreen` (iOS-M6 ruling 1).
//
// TOOLCHAIN NOTE, the same one every `*Strings.swift` carries: a `.xcstrings` is compiled into
// `.lproj/Localizable.strings` by **Xcode's** build system only, so the pin test
// (`SalusTestingTests.AppStringCatalogTests`) asserts against the FILE and the end-to-end check
// is the simulator run.

import Foundation

/// The strings the app shell owns.
enum AppStrings {
    /// `more_cycle` — "Regl Takibi" / "Cycle tracking".
    static var moreCycle: String { localized(.moreCycle) }

    /// `more_cycle_subtitle` — "Takvim, tahminler ve belirtiler" / "Calendar, predictions and
    /// symptoms".
    static var moreCycleSubtitle: String { localized(.moreCycleSubtitle) }

    /// The catalog keys, named once and Android-verbatim.
    enum Key: String, CaseIterable {
        case moreCycle = "more_cycle"
        case moreCycleSubtitle = "more_cycle_subtitle"
    }

    private static func localized(_ key: Key) -> String {
        String(localized: String.LocalizationValue(key.rawValue), bundle: .main)
    }
}
