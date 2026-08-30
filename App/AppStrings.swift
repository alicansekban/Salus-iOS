// The app target's own String Catalog, and the first one it has ever had.
//
// Every other catalog in the tree belongs to a package and is read through `Bundle.module`
// (`VitalsStrings.swift` is the shape). The shell has no module bundle — its resources are the
// main bundle's — so this enum is the same typed accessor over `Bundle.main`, and the reason it
// exists is the same: a bare `String(localized:)` at a call site names its key inline, where a
// typo ships the key as the label instead of failing to compile.
//
// WHAT THE SHELL PERMANENTLY OWNS. The three `app_lock_*` keys, added with iOS-M8. They are
// Android's **app module** strings (`app/src/main/res/values{,-en}/strings.xml:11-13`) because the
// lock gate is the app's on that side too: `AppLockScreen` sits in `com.alicansekban.salus.lock`,
// not in a feature module. The iOS split is the same one — `App/Lock/` draws them, and
// `FeatureSettings` owns the `settings_app_lock_*` copy that describes the *setting*.
//
// WHY THE TWO `more_cycle*` COPIES ARE STILL HERE. They are Android's `feature/settings` strings
// (`MoreScreen.kt:222-231`), and they now exist in `FeatureSettings`' own catalog too, where the
// M8 More hub reads them. The copies below stay only as long as `PlaceholderScreen` does: it is
// still the More tab at this point in the milestone, and it is the one thing that draws them. Both
// accessors, both catalog entries and `PlaceholderScreen` are deleted together when the shell
// mounts the real hub (iOS-M6 ruling 1, closed by M8's shell task) — at which point
// `AppStringCatalogTests` pins the three `app_lock_*` keys alone.
//
// TOOLCHAIN NOTE, the same one every `*Strings.swift` carries: a `.xcstrings` is compiled into
// `.lproj/Localizable.strings` by **Xcode's** build system only, so the pin test
// (`SalusTestingTests.AppStringCatalogTests`) asserts against the FILE and the end-to-end check
// is the simulator run.

import Foundation

/// The strings the app shell owns.
enum AppStrings {
    /// `app_lock_locked_title` — "Salus kilitli" / "Salus is locked".
    static var appLockLockedTitle: String { localized(.appLockLockedTitle) }

    /// `app_lock_unlock` — "Kilidi aç" / "Unlock".
    static var appLockUnlock: String { localized(.appLockUnlock) }

    /// `app_lock_prompt_title` — "Salus kilidini aç" / "Unlock Salus". The reason `LAContext` shows
    /// above its own sheet, the twin of `PromptInfo.setTitle` (`MainActivity.kt:130`).
    static var appLockPromptTitle: String { localized(.appLockPromptTitle) }

    /// `more_cycle` — "Regl Takibi" / "Cycle tracking". Dies with `PlaceholderScreen`.
    static var moreCycle: String { localized(.moreCycle) }

    /// `more_cycle_subtitle` — "Takvim, tahminler ve belirtiler" / "Calendar, predictions and
    /// symptoms". Dies with `PlaceholderScreen`.
    static var moreCycleSubtitle: String { localized(.moreCycleSubtitle) }

    /// The catalog keys, named once and Android-verbatim.
    enum Key: String, CaseIterable {
        case appLockLockedTitle = "app_lock_locked_title"
        case appLockUnlock = "app_lock_unlock"
        case appLockPromptTitle = "app_lock_prompt_title"
        case moreCycle = "more_cycle"
        case moreCycleSubtitle = "more_cycle_subtitle"
    }

    private static func localized(_ key: Key) -> String {
        String(localized: String.LocalizationValue(key.rawValue), bundle: .main)
    }
}
