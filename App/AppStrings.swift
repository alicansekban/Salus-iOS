// The app target's own String Catalog, and the first one it has ever had.
//
// Every other catalog in the tree belongs to a package and is read through `Bundle.module`
// (`VitalsStrings.swift` is the shape). The shell has no module bundle — its resources are the
// main bundle's — so this enum is the same typed accessor over `Bundle.main`, and the reason it
// exists is the same: a bare `String(localized:)` at a call site names its key inline, where a
// typo ships the key as the label instead of failing to compile.
//
// WHAT THE SHELL PERMANENTLY OWNS. Eight keys, both groups Android's **app module** strings,
// because both surfaces are the app's on that side too.
//
//   The three `app_lock_*` (`app/src/main/res/values{,-en}/strings.xml:11-13`), added with iOS-M8
//   T9: `AppLockScreen` sits in `com.alicansekban.salus.lock`, not in a feature module. The iOS
//   split is the same one — `App/Lock/` draws them, and `FeatureSettings` owns the
//   `settings_app_lock_*` copy that describes the *setting*.
//
//   The five `nav_*` (`…/strings.xml:5-10`, minus `nav_cycle` — see below), added with iOS-M8 T12
//   under controller ruling H-10. `RootTab` had carried five hardcoded English words since M0
//   (`placeholderLabel`, whose own comment said they were "expected to be deleted — not
//   translated"), which left a Turkish app with an English tab bar and made §6.4's TR default a
//   half-truth on the most visible surface there is. Ruling 9 had fixed this catalog at three keys;
//   H-10 reads that ruling as the `AppStrings`/`more_cycle*` cleanup it was, not a ban on the shell
//   owning the strings the shell draws.
//
// `nav_cycle` (`…/strings.xml:7`, "Döngü" / "Cycle") is deliberately NOT here: Android still
// declares it but nothing references it — `SalusApp.kt:80-84` lists five `TopLevelDestination`s and
// the cycle tab was removed by the M9 restructure. Porting a dead key would put a string in the
// bundle no screen can ever draw. `app_name` (`…/strings.xml:3`) is not here either: its twin is
// `CFBundleDisplayName` in `project.yml`, which is where iOS reads the springboard label from.
//
// The two `more_cycle*` copies that lived here while `PlaceholderScreen` drew the cycle row were
// deleted with it in iOS-M8 T6: the More hub now owns the row and reads `FeatureSettings`' own
// copies.
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

    /// `nav_*` — the tab-bar label for each ``RootTab``, in the Android list's order
    /// (`SalusApp.kt:80-84`).
    ///
    /// A function rather than five call sites so the tab bar cannot draw a label for one tab and
    /// the icon of another: `RootTab.label` is the only reader, and this switch is total.
    static func nav(_ tab: RootTab) -> String {
        switch tab {
        case .home: localized(.navHome)
        case .medications: localized(.navMedications)
        case .vitals: localized(.navVitals)
        case .appointments: localized(.navAppointments)
        case .more: localized(.navMore)
        }
    }

    /// The catalog keys, named once and Android-verbatim.
    enum Key: String, CaseIterable {
        case appLockLockedTitle = "app_lock_locked_title"
        case appLockUnlock = "app_lock_unlock"
        case appLockPromptTitle = "app_lock_prompt_title"
        case navHome = "nav_home"
        case navMedications = "nav_medications"
        case navVitals = "nav_vitals"
        case navAppointments = "nav_appointments"
        case navMore = "nav_more"
    }

    private static func localized(_ key: Key) -> String {
        String(localized: String.LocalizationValue(key.rawValue), bundle: .main)
    }
}
