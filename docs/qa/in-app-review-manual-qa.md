# In-app review — manual QA (iOS)

Spec: `salus-android/docs/superpowers/specs/2026-09-06-in-app-review-design.md`.
Plan: `docs/superpowers/plans/2026-09-06-in-app-review-ios.md`. Branch `feature/in-app-review`.

What the automated gate already proves (`scripts/ci.sh`): the policy table (3 opens, 14-day
cooldown, boundary cases), the two preference keys round-trip, the Home ViewModel emits exactly one
`requestReview` on the third arrival and stamps the clock first, a foreground return counts only
while Home is showing, and the More row emits the App Store write-review URL. What follows is the
UIKit/StoreKit side no host test can reach.

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
2. **Expected:** unlocking does not double-count the open (the signal fires once per `.active`;
   the count moves by one per return).

## Parity-ledger entry (proposed, for `salus-android/docs/parity-ledger.md`)

```
| In-app review (2026-09-06) | keys `home_open_count` / `review_last_requested_ms` on both; `ReviewPromptPolicy` (3 opens, 14 d) in :core:common / SalusCommon | iOS-only `AppForegroundSignal` (SalusCommon): Android's `LifecycleResumeEffect` re-fires on foreground, SwiftUI's `.task` does not, so the shell's `.active` arm fans out to `HomeViewModel.sceneDidBecomeActive()`, which counts only while Home is visible | More row: Android `market://` + web fallback, iOS `apps.apple.com/app/id6807102436?action=write-review` via `MoreEffect.openUrl` | `ReviewState` lives in SalusSettings (one consumer) rather than SalusModel |
```
