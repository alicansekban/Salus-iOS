// The half of Android's lock gate that lives in `MainActivity` rather than in `AppLockScreen`:
// `AppLockScreen(onUnlockRequest = { showUnlockPrompt(appLockManager::unlock) })`
// (`app/src/main/kotlin/com/alicansekban/salus/MainActivity.kt:99-103`, `:118-134`).
//
// A view of its own rather than three lines inside `RootView` for one reason worth writing down:
// `AppLockScreen` is drawing and `AppLockManager` is state, and the wire between them is neither.
// Keeping it here puts all three lock files in `App/Lock/` and keeps the shell's own file about
// the shell — the same split `App/Reminder/` already has.
//
// It takes the manager rather than the whole composition root, because that is all it needs: the
// gate reads nothing else, and a parameter says so where an `@Environment(AppCompositionRoot.self)`
// would leave a reader looking for what else it reaches.

import SalusCommon
import SwiftUI

/// The app-lock gate: the locked screen, plus the biometric prompt it fires.
struct AppLockGate: View {
    let manager: AppLockManager

    var body: some View {
        AppLockScreen(onUnlockRequest: requestUnlock)
    }

    /// `showUnlockPrompt(appLockManager::unlock)` (`MainActivity.kt:101`).
    ///
    /// Fired by `AppLockScreen` on appearance and again on every tap of its button. A fresh
    /// `LAContext` per attempt — see ``makeLockPrompt()``, which is also what the More hub's
    /// enable-re-auth interception uses. `false` is Kotlin's missing error callback: nothing
    /// happens, no message is shown, and the button is the retry.
    private func requestUnlock() {
        let prompt = makeLockPrompt()
        Task { @MainActor in
            guard await prompt(AppStrings.appLockPromptTitle) else { return }
            manager.unlock()
        }
    }
}
