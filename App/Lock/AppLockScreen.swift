// Ported 1:1 from Android
// `app/src/main/kotlin/com/alicansekban/salus/lock/AppLockScreen.kt:30-60`.
//
// Everything the screen does is in three lines of Kotlin, and all three carry over:
//
//   * `LaunchedEffect(Unit) { onUnlockRequest() }` (`AppLockScreen.kt:32`) → `.task`, which SwiftUI
//     runs when the view appears and cancels when it goes away. The prompt therefore fires by
//     itself; the button below is only the retry.
//   * `Surface(fillMaxSize, color = background)` (`:34-37`) → the background token painted under a
//     `ZStack`, `ignoresSafeArea()` because `fillMaxSize` inside `setContent` covers the whole
//     window. Compose's `Surface` also sets the content colour, which is what `onBackground` on the
//     title below spells out.
//   * no back handling (`AppLockScreen.kt:27-28`) → nothing here declares a toolbar, a
//     `NavigationStack` or a dismiss. The gate is an overlay the shell (T11) draws **above** the
//     tab bar and outside every `NavigationStack`, so the back stack and any pending deep link
//     survive the lock instead of being popped by it.
//
// There is no test for this file and there is not meant to be: the app target has no test bundle
// (`project.yml`'s `scheme.testTargets: []`), and the logic it would test — when the gate is up —
// is `SalusCommon.AppLockManager`, which is covered case for case. What is left here is drawing,
// and drawing is checked by `scripts/m8-manual-qa.md` §3.

import SalusDesignSystem
import SalusUI
import SwiftUI

/// The full-screen gate shown while the app is locked.
///
/// - Parameter onUnlockRequest: fired once on appearance and again on every tap of the button —
///   the shell turns it into ``makeLockPrompt()`` and, on success, `AppLockManager.unlock()`.
struct AppLockScreen: View {
    let onUnlockRequest: () -> Void

    @Environment(\.salusTheme) private var theme

    var body: some View {
        ZStack {
            theme.colorScheme.background
                .ignoresSafeArea()

            // Spacing is per-gap in Kotlin (`Spacer(height = …)` between children), not one uniform
            // step, so the stack carries none and each gap is spelled out as it is there.
            VStack(spacing: 0) {
                // `SalusIconBadge(Icons.Outlined.Lock, LargeSize, LargeIconSize)`
                // (`AppLockScreen.kt:43-47`) — no accent, so the primary role.
                SalusIconBadge(
                    systemImage: "lock",
                    size: SalusIconBadgeDefaults.largeSize,
                    iconSize: SalusIconBadgeDefaults.largeIconSize
                )
                Spacer().frame(height: SalusSpacing.lg)
                // `Text(app_lock_locked_title, style = titleLarge)` (`AppLockScreen.kt:49-52`).
                // `Text(verbatim:)` because the value is already resolved — `Text(_:)` would read
                // it back as a `LocalizedStringKey` against the main bundle.
                Text(verbatim: AppStrings.appLockLockedTitle)
                    .font(SalusTypography.titleLarge.font)
                    .tracking(SalusTypography.titleLarge.tracking)
                    .foregroundStyle(theme.colorScheme.onBackground)
                    .multilineTextAlignment(.center)
                Spacer().frame(height: SalusSpacing.xl)
                // `SalusPillButton(app_lock_unlock, onClick = onUnlockRequest)`
                // (`AppLockScreen.kt:54-57`) — the retry after a cancelled or failed prompt.
                SalusPillButton(text: AppStrings.appLockUnlock, action: onUnlockRequest)
            }
        }
        // `LaunchedEffect(Unit) { onUnlockRequest() }` (`AppLockScreen.kt:32`).
        .task { onUnlockRequest() }
    }
}

#Preview("App lock") {
    // `@PreviewLightDark AppLockScreenPreview` (`AppLockScreen.kt:62-68`); the light half, which is
    // the one this preview macro draws.
    let theme = SalusTheme.resolve(systemIsDark: false)
    return AppLockScreen(onUnlockRequest: {})
        .salusTheme(theme)
}
