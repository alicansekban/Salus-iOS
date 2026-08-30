// The iOS half of Android's `MainActivity.showUnlockPrompt`
// (`app/src/main/kotlin/com/alicansekban/salus/MainActivity.kt:118-134`).
//
// Kotlin's prompt is a `BiometricPrompt` with
// `setAllowedAuthenticators(BIOMETRIC_WEAK or DEVICE_CREDENTIAL)` — biometrics **or** the device
// credential, with the system drawing the PIN/pattern/password sheet itself when biometry is
// unavailable, not enrolled, or refused. `LAPolicy.deviceOwnerAuthentication` is that exact pair:
// Face ID / Touch ID with an automatic passcode fallback. (`.deviceOwnerAuthenticationWithBiometrics`
// is the twin of `BIOMETRIC_STRONG` alone, and it is deliberately not what this uses — a phone with
// no enrolled face still has a passcode, and Android would let that in.)
//
// **On failure or cancel, nothing happens.** Kotlin overrides only `onAuthenticationSucceeded`
// (`MainActivity.kt:122-126`) — there is no error callback, no retry loop and no message. The gate
// stays up and `AppLockScreen`'s Unlock button is the retry. `false` here is that silence: every
// caller is written as "unlock only on true".
//
// It is a factory returning a closure rather than a protocol because there is exactly one
// implementation and one seam: the app target has no test bundle (`project.yml`'s
// `scheme.testTargets: []`), so a protocol would buy a fake nothing could run. What is testable —
// the whole of the gate's logic — lives in `SalusCommon.AppLockManager` instead.
//
// A fresh `LAContext` per evaluation on purpose: a context caches its last successful
// authentication for `touchIDAuthenticationAllowableReuseDuration`, and re-using one would let a
// second lock be opened by the first unlock.

import LocalAuthentication

/// Builds the authentication prompt the lock gate fires.
///
/// The returned closure takes the reason the system shows above its own sheet — `app_lock_prompt_title`
/// for the gate (`MainActivity.kt:130`), `settings_app_lock_confirm_title` for the settings toggle
/// that enables the lock (M8 ruling 4) — and answers whether the person authenticated.
@MainActor
func makeLockPrompt() -> @MainActor (String) async -> Bool {
    { localizedReason in
        let context = LAContext()
        do {
            return try await context.evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason: localizedReason
            )
        } catch {
            // Cancel, lockout, no passcode set — all of them are Kotlin's missing error callback.
            return false
        }
    }
}
