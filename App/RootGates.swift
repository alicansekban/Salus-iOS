// The shell's gate order, extracted from `RootView` so the one part of it that is logic rather
// than drawing can be read (and reasoned about) on its own.
//
// Ported 1:1 from `app/src/main/kotlin/com/alicansekban/salus/MainActivity.kt:47-107`, whose whole
// gate story is four lines spread over two places:
//
//   * `installSplashScreen().setKeepOnScreenCondition { onboardingCompleted.value == null }`
//     (`MainActivity.kt:48`) with `onboardingCompleted` a `MutableStateFlow<Boolean?>(null)` whose
//     KDoc is "Null until DataStore has answered; the splash stays up so Home never flashes"
//     (`:44-45`). iOS has no `installSplashScreen`, so the hold is a blank frame this shell draws
//     itself — recorded divergence (f).
//   * `if (isLocked) { AppLockScreen(...) }` then `if (onboardingDone == false) { OnboardingRoute() }`
//     (`:99-106`). Compose draws siblings in source order, so the *later* one is on top:
//     "Overlays, not destinations: the back stack and pending notification deep links stay intact
//     behind the gates. Onboarding sits outermost — a first launch has nothing to lock"
//     (`:96-98`, Android's comment verbatim; global constraints, ruling 3).
//
// TWO THINGS THIS ADDS TO THE KOTLIN, both of them the iOS shape of something Android gets free:
//
//   1. **The lock waits for `hasReadSetting`.** Kotlin collects `isLocked` with
//      `initialValue = false` (`MainActivity.kt:84-85`); the iOS `AppLockManager` starts `true`
//      instead, because `RootView` renders synchronously while the setting stream's first emission
//      is a task hop away and drawing the app's contents to someone the lock was meant to stop is
//      the worse of the two failures (`AppLockManager.swift`, divergence 3). The cost of that
//      choice is that "locked" also means "nobody has read the setting yet", and a gate drawn in
//      *that* window fires `AppLockScreen`'s automatic Face ID prompt at a user who never enabled
//      the lock. `hasReadSetting` is the manager's own signal that the window has closed, and this
//      is the line that honours it (T9 hand-off D-9-b).
//   2. **Nothing is drawn while the splash is held.** Kotlin cannot draw a gate under the system
//      splash either, but there it is the platform's doing; here it is this line. Ruling 3's
//      wording is what it implements: while `onboardingCompleted` is nil the shell draws the blank
//      frame and "never the TabView, never a wrong gate".
//
// A `struct` of three booleans rather than a single "which gate wins" enum, because the gates are
// not exclusive on Android and must not become exclusive here: a reinstall keeps `app_lock_enabled`
// (it lives in the Keychain, spec §5) while clearing `onboarding_completed`, so a real device can
// want both at once — and Kotlin draws both, with onboarding on top. Folding that into one case
// would silently change which of the two the user is answering.
//
// There is no test for this file and there is not meant to be: the app target has no test bundle
// (`project.yml`'s `scheme.testTargets: []`, the M8 plan's "no app test target" user decision). It
// is pure, total and compile-checked, and `scripts/m8-manual-qa.md` §3 and §7 are where the three
// orderings are walked by hand.

import SalusDesignSystem
import SwiftUI

/// Which of the shell's covers are up, in z-order — `holdsSplash` and `showsLock` beneath
/// `showsOnboarding`, exactly as `MainActivity.kt:94-107` lists them.
struct RootGates: Equatable {
    /// The splash-hold: `userSettings` has not answered yet, so nothing is known and nothing but
    /// the blank frame may be drawn (ruling 3, divergence (f)).
    let holdsSplash: Bool

    /// The app-lock gate — `if (isLocked)` (`MainActivity.kt:99`), plus the `hasReadSetting` guard
    /// described in this file's header.
    let showsLock: Bool

    /// The onboarding gate — `if (onboardingDone == false)` (`MainActivity.kt:104`). `== false`,
    /// not `!`: `nil` is the splash-hold, not "not completed".
    let showsOnboarding: Bool

    /// - Parameters:
    ///   - onboardingCompleted: the `onboarding_completed` setting, `nil` until the first
    ///     `userSettings` emission — `MutableStateFlow<Boolean?>(null)` (`MainActivity.kt:45`).
    ///   - lockHasReadSetting: `AppLockManager.hasReadSetting`. See the header: without it the
    ///     manager's fail-safe `isLocked == true` would be drawn as a real gate.
    ///   - isLocked: `AppLockManager.isLocked` (`MainActivity.kt:84-85`).
    static func resolve(
        onboardingCompleted: Bool?,
        lockHasReadSetting: Bool,
        isLocked: Bool
    ) -> RootGates {
        let holdsSplash = onboardingCompleted == nil
        return RootGates(
            holdsSplash: holdsSplash,
            // `!holdsSplash` is not redundant with `lockHasReadSetting` and must not be simplified
            // away: the two flags come from two independent subscriptions to the same
            // `userSettings` stream (the manager's, opened in the composition root, and the
            // shell's), so the manager can answer first. Without this the lock would be drawn —
            // and its automatic prompt fired — during a hold that is meant to show nothing.
            showsLock: !holdsSplash && lockHasReadSetting && isLocked,
            showsOnboarding: onboardingCompleted == false
        )
    }
}

/// The blank frame that stands in for `installSplashScreen` (`MainActivity.kt:48`) — recorded
/// divergence (f).
///
/// `UILaunchScreen` in `Info.plist` holds the screen until the first frame is ready; from there on
/// it is this. The background *role* rather than a fixed colour, so a device in dark mode holds on
/// the dark ground and the hand-off to whatever is drawn next is invisible — and the role is the
/// right one to read even before `theme_mode` has been answered, because `ThemeMode.default` is
/// `.system`, which is exactly what the launch screen was already following.
///
/// `.contentShape(.rect)` because the shell underneath it is live and laid out: the cover has to
/// take the taps as well as the pixels. Hidden from VoiceOver because it names nothing to act on.
struct SplashHoldCover: View {
    @Environment(\.salusTheme) private var theme

    var body: some View {
        theme.colorScheme.background
            .ignoresSafeArea()
            .contentShape(.rect)
            .accessibilityHidden(true)
    }
}
