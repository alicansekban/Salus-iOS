# In-app review — manual QA (iOS)

Spec: `salus-android/docs/superpowers/specs/2026-09-06-in-app-review-design.md`.
Plan: `docs/superpowers/plans/2026-09-06-in-app-review-ios.md`. Branch `feature/in-app-review`.

What the automated gate already proves (`scripts/ci.sh`): the policy table (3 opens, 14-day
cooldown, boundary cases), the two preference keys round-trip, the Home ViewModel emits exactly one
`requestReview` on the third arrival and stamps the clock first, a foreground return counts only
while Home is showing, the cold start counts once rather than twice (the launch's `.active` is not
a return), a return onto the app-lock gate counts only once the gate lifts, and the More row emits
the App Store write-review URL. What follows is the UIKit/StoreKit side no host test can reach.

## 1. The rating sheet on the third open (simulator)

The simulator shows the StoreKit sheet on **every** `requestReview` call; a device honours
Apple's cap (about three a year, and never twice within days), so use the simulator to see it and
a device only to confirm nothing crashes.

1. Fresh install (delete the app first so `home_open_count` starts at 0). Finish onboarding.
2. Home is showing → that is open **1**. Nothing appears.
3. Background the app (Home button / swipe up) and return → open **2**. Nothing appears.
4. Background and return again → open **3**. **Expected:** the StoreKit rating sheet appears over
   Home.
5. Dismiss it. Background and return → open 4. **Expected:** no sheet (14-day cooldown).
6. Switch to the Medications tab, background, return. **Expected:** no sheet, and the count did
   not move — a foreground return while another tab is showing is not a Home open. (Verify by
   returning to Home, then backgrounding/returning twice more: still no sheet, because the
   cooldown, not the count, is what holds now.)

To re-test the cooldown without waiting 14 days, delete the app (the counters live in
`UserDefaults`) or move the device clock forward 14 days in Settings.

## 2. The "Rate Salus" row

1. More → App section → **Rate Salus** (TR: "Bizi değerlendirin"), below About.
2. **Expected:** the App Store opens (or Safari, on a simulator without the App Store) at
   `https://apps.apple.com/app/id6807102436?action=write-review`. Until the listing is approved on
   App Store Connect the page is a 404 — that is the store's state, not a bug in the row; the URL
   is stable and lights up with the listing.
3. **Expected:** no StoreKit sheet from this row, ever. The row is a link.

## 3. Lock screen + foreground

1. Enable app lock. Background and return so the lock gate shows.
2. **Expected:** no rating sheet appears over the lock gate — not even when this return is the
   third open. The count does not move while the gate is up.
3. Unlock (Face ID / passcode). **Expected:** the count moves by exactly one, and if that open is
   the third the sheet appears now, over Home, with the gate already gone.
4. Background and return a second time, unlock again. **Expected:** the count moves by exactly one
   more — a locked return is deferred, never dropped and never doubled.

## 4. Cold start counts once

1. Delete the app and reinstall (`home_open_count` back to 0). Finish onboarding.
2. Reach Home, then background and return **twice**. **Expected:** the sheet appears on the second
   return — that is opens 1 (launch), 2 and 3. If it appeared on the *first* return the launch was
   counted twice, which is the bug the signal's arming guard exists for.

## Parity-ledger entry (proposed, for `salus-android/docs/parity-ledger.md`)

```
| In-app review (2026-09-06) | keys `home_open_count` / `review_last_requested_ms` on both; `ReviewPromptPolicy` (3 opens, 14 d) in :core:common / SalusCommon | iOS-only `AppForegroundSignal` (SalusCommon): Android's `LifecycleResumeEffect` re-fires on foreground, SwiftUI's `.task` does not, so the shell's `.active` arm fans out to `HomeViewModel.sceneDidBecomeActive()`, which counts only while Home is visible. Two iOS-only guards on that fan-out, both from the platform and neither with an Android twin: it is armed by `.background` (a cold start's own `.active` would otherwise double-count the launch `.task` already counted), and a return onto the app-lock gate is held until `AppLockManager.didUnlock` — the gate is a `ZStack` overlay, so Home never disappears behind it, where Android's gate replaces the screen | More row: Android `market://` + web fallback, iOS `apps.apple.com/app/id6807102436?action=write-review` via `MoreEffect.openUrl` | `ReviewState` lives in **iOS `SalusSettings`** where Android keeps it in **`:core:model`** — the one place the module mirror does not hold for this feature (single consumer; keeps `SalusModel` free of a settings-only type). A second consumer on iOS would move it. |
```
