# iOS-M9 manual QA — premium, the paywall and premium themes

iOS-M9's acceptance is *RevenueCat billing, the paywall sheet, the intro paywall and premium
themes*. The automated half is mapped case-by-case in the execution record of
`docs/superpowers/plans/2026-08-31-ios-m9-premium.md` — the `PaywallViewModel` 21-case table, the
`PaywallFeatureListTests` 4-shipped-features invariant, the `IntroPaywallGate` cases, the string
parity. This document is the other half: everything that needs a tap, a real store, and the shell
wiring that only a running app exercises.

**Agents do not run this script.** From 2026-08-30 the simulator and device passes are the user's
(the coordinator's decision, recorded in the ledger); implementers run tests, lint and the build,
and write this file from the code. Every step below says **NOT RUN** until someone runs it.

Each section is written by the task that shipped the behaviour it checks, so the file grows a
section at a time and the numbering follows the plan rather than the reading order.

**Language.** The steps quote the Turkish strings, which is what a default simulator shows
(spec §6.4 — Turkish is the default *and* the fallback).

---

## §1. The paywall sheet (Task 6)

Written by Task 6 (`Packages/Features/FeaturePaywall/Sources/FeaturePaywall/ui/PaywallSheet.swift`,
`PaywallRoute.swift`). The automated half is `PaywallFeatureListTests` (the 4-shipped-features
invariant) plus the `PaywallViewModel` table; what no test can reach is the rendered sheet — the
plan cards, the badge, the CTA, the policy links — which is visual and runs only on a device or
simulator.

**Before you start — the sheet is not yet reachable.** Task 6 ships the sheet and its route; the
shell that presents it (`PaywallHost`, a `fullScreenCover` driven by `PaywallController.request`)
lands in **Task 9**. Until then the rows below cannot be reached from the app. If you cannot open
the paywall, run §2 first and stop there.

**How to open the paywall.** The sheet is presented by the shell's `PaywallHost` whenever
`PaywallController.request != nil`. The two entry points that exist by the end of M9 are the
settings premium row (More → the premium row) and the post-onboarding intro. A free user tapping
the settings row opens the paywall with the generic headline; the intro opens it with the
`.onboarding` source.

**How to get a store offering.** The sheet needs `Purchases.currentOffering()` to return plans,
which requires a configured RevenueCat key (`Secrets.local.xcconfig`) and a store configuration
with at least one product. Without a key the sheet shows the `offeringUnavailable` empty state
(§1.2). With a sandbox configuration it shows the three plan cards (§1.3).

| # | Step | Expected | Status |
|---|------|----------|--------|
| 1.1 | Open the paywall (settings premium row). | The sheet slides up full-screen over the tab bar, with a close button (top-right, `paywall_close` "Kapat") and a loading spinner while the offering loads. | **NOT RUN** |
| 1.2 | Open the paywall with no RevenueCat key (blank `Secrets.local.xcconfig`). | The body shows the `paywall_error_offering` text ("Planlar şu an yüklenemedi…") centred, and the actions show a "Tekrar dene" retry pill plus "Satın almaları geri yükle". No crash. | **NOT RUN** |
| 1.3 | Open the paywall with a sandbox offering of three plans (annual, six-month, monthly). | The body shows the headline (generic for settings), the subtitle, the four feature rows in order (AI özetleri, PDF rapor, trend analizi, premium temalar), then the three plan cards **annual first**, then six-month, then monthly. | **NOT RUN** |
| 1.4 | Inspect the annual plan card. | It carries the "En avantajlı" (best value) badge, its per-month line ("Ayda ₺41,67"), and its price. It is pre-selected (the radio ring is filled). | **NOT RUN** |
| 1.5 | Inspect the six-month and monthly cards. | Six-month shows its per-month line; monthly shows no per-month line (there is nothing to divide). Neither is selected. | **NOT RUN** |
| 1.6 | Tap the monthly card. | The selection ring moves to monthly; the CTA label changes from "7 gün ücretsiz dene" (annual has a free trial) to "Abone ol" (monthly has none). | **NOT RUN** |
| 1.7 | Tap the CTA. | The store sheet opens (sandbox). On success the paywall dismisses; on cancel it stays open with no error; on failure it shows the `paywall_error_purchase` line above the CTA. | **NOT RUN** |
| 1.8 | Tap "Satın almaları geri yükle" (restore). | A restore runs; with no entitlement it shows the `paywall_error_restore` line; with one it dismisses. | **NOT RUN** |
| 1.9 | Inspect the bottom block. | Below the CTA and restore sit the renewal note ("Abonelik, iptal edilmediği sürece dönem sonunda otomatik yenilenir…") and the two policy links "Abonelik şartları" and "Gizlilik politikası". | **NOT RUN** |
| 1.10 | Tap "Abonelik şartları". | The terms URL opens in the browser (Safari). | **NOT RUN** |
| 1.11 | Tap "Gizlilik politikası". | The privacy URL opens in the browser. | **NOT RUN** |
| 1.12 | Tap the close button. | The paywall dismisses (slides down) and the app returns to where it was. | **NOT RUN** |
| 1.13 | VoiceOver: swipe through the sheet. | The close button reads "Kapat"; each feature row reads its label once (the icon is hidden); each plan card reads as a selected/unselected radio; the CTA, restore and policy links are reachable. | **NOT RUN** |
| 1.14 | Dynamic Type at AX5 (Turkish). | The headline, feature rows, plan cards and actions all scale; nothing clips or overlaps. | **NOT RUN** |

---

## §2. The shell wiring (Task 9)

Written by Task 9 (`App/SalusApp.swift`, `App/AppCompositionRoot.swift`, `App/PaywallHost.swift`,
`App/RootView.swift`). The automated half is the fake-backed repository/gate tests plus the
intro-gate cases; what no test can reach is a running app with a real (or missing) store key — the
keyless build, the `PaywallHost` cover over the shell, the theme that repaints on entitlement, and
the once post-onboarding announcement.

**Before the rows below make sense.** The app now configures RevenueCat in `SalusApp.init` when
`SALUS_REVENUECAT_API_KEY` is non-blank (read from the git-ignored `App/Secrets.local.xcconfig`).
The composition root wires the real `PremiumRepository`, `PaywallController`, `PaywallModule` and
`IntroPaywallGate`; `RootView` mounts `PaywallHost` (a `fullScreenCover`) above the `TabView` and
resolves the theme from `effectivePremiumTheme(status, storedTheme)`.

| # | Step | Expected | Status |
|---|------|----------|--------|
| 2.1 | Build and launch with a blank `Secrets.local.xcconfig` (no RevenueCat key). | The app launches and runs **fully free**: no crash, no premium features unlocked, and the tab bar draws the classic palette. The paywall, opened from More or the intro, shows the `paywall_error_offering` state ("Planlar şu an yüklenemedi…") plus "Tekrar dene" and "Satın almaları geri yükle". | **NOT RUN** |
| 2.2 | Open the paywall from the More premium row. | The `PaywallHost` `fullScreenCover` slides up full-screen **over the tab bar** (the tab bar is covered, not pushed away). It closes with the sheet's close button (slides down), returning to wherever the user was. | **NOT RUN** |
| 2.3 | Set a premium theme (e.g. `OCEAN`) in the More → theme dialog while FREE. | The tab bar and app keep drawing **classic**: `effectivePremiumTheme` downgrades a non-premium user to `.classic` regardless of the stored selection. | **NOT RUN** |
| 2.4 | Purchase premium (sandbox) with a theme selected. | The theme **unlocks**: the palette repaints to the stored selection (e.g. ocean) everywhere it is drawn, without relaunch. Backing out of the store sheet and re-opening also keeps the entitlement. | **NOT RUN** |
| 2.5 | Force the entitlement to lapse (cancel the subscription, let the grace period end). | The theme **lapses back to classic**: a previously-premium user returns to the classic palette once the store reports FREE, and the stored `premium_theme` selection is retained for a future resubscribe. | **NOT RUN** |
| 2.6 | Complete onboarding on a **fresh install** (post-onboarding intro). | The intro paywall fires **once**, after onboarding completes, with the `.onboarding` headline. It does not fire on a subsequent launch (the `paywall_intro_shown` flag is set). | **NOT RUN** |
| 2.7 | Launch a second time after the intro has shown. | The intro does **not** appear again; the app opens straight to the shell. | **NOT RUN** |
| 2.8 | With a key-less build, complete onboarding. | The intro paywall does **not** fire (nothing can be sold), and `paywall_intro_shown` is **not** marked — so a later keyed build still gets to announce premium once. | **NOT RUN** |
