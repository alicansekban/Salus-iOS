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

---

## §3. The entitlement lifecycle (Task 10)

Written by Task 10 from the `SalusPremium` repository and gateway
(`Packages/SalusPremium/Sources/SalusPremium/PremiumRepository.swift`,
`RevenueCatPurchasesGateway.swift`) and the shell theme resolution (`App/RootView.swift`). The
automated half is the `PremiumRepositoryImplTests` 5-case table plus the `EffectiveThemeTests`
4-case table; what no test can reach is a real sandbox store, a real cancellation, and the
offline path — the store's own state machine, which only a device with a sandbox account
exercises.

**How the status flows.** `PremiumRepositoryImpl` seeds `.free`, then maps every
`Purchases.customerInfoStream` update through `premiumStatusOf(entitlementActive:hasBillingIssue:)`
— an active entitlement with a billing issue is `.gracePeriod`, without one `.premium`, and an
inactive entitlement is `.free` whatever the billing flag says. `RootView` mirrors
`premiumRepository.status` and resolves the palette with
`effectivePremiumTheme(status, storedTheme)`: a `.premium`/`.gracePeriod` user keeps the stored
selection, a `.free` user is drawn `.classic` regardless.

| # | Step | Expected | Status |
|---|------|----------|--------|
| 3.1 | Purchase premium (sandbox) with a theme selected (e.g. `OCEAN`). | The theme **unlocks**: the palette repaints to the stored selection everywhere it is drawn, without relaunch. Backing out of the store sheet and re-opening also keeps the entitlement. | **NOT RUN** |
| 3.2 | Cancel the subscription in the sandbox store, then let the grace period end. | The theme **lapses back to classic**: a previously-premium user returns to the classic palette once the store reports `.free`, and the stored `premium_theme` selection is retained for a future resubscribe. | **NOT RUN** |
| 3.3 | Restore purchases with an active entitlement (a second device, or after a reinstall). | The restore finds the entitlement, refreshes the repository, and the theme unlocks. | **NOT RUN** |
| 3.4 | Restore purchases with **no** entitlement (a fresh sandbox account). | The restore runs, finds nothing, and the paywall shows the `paywall_error_restore` line ("Mağazaya ulaşılamadı ya da bu hesapta bir abonelik bulunamadı.") — the app stays free. | **NOT RUN** |
| 3.5 | Purchase premium, then go **offline** (airplane mode) and relaunch. | The cached entitlement stays: the app still draws the premium theme from the last known status — the repository keeps the last non-nil snapshot and never downgrades on a store that does not answer. | **NOT RUN** |

---

## §4. The intro paywall (Task 10)

Written by Task 10 from `IntroPaywallGate` (`Packages/Features/FeaturePaywall/Sources/FeaturePaywall/domain/IntroPaywallGate.swift`)
and its `RootView` `.task` mount. The automated half is the `IntroPaywallGateTests` 4-case table
(waits for onboarding, marks-before-shows, never re-marks, keyless no-op); what no test can reach
is a real first launch on a device — the once-per-install announcement.

**How it fires.** `IntroPaywallGate.run()` guards on `isBillingConfigured()` (a keyless build
returns immediately, flag untouched), waits for `userSettings.first { $0.onboardingCompleted }`,
checks `paywall_intro_shown`, marks it shown **before** opening the paywall (process-death-safe),
then `paywallController.show(.onboarding)`.

| # | Step | Expected | Status |
|---|------|----------|--------|
| 4.1 | Fresh install, complete onboarding (keyed build). | The intro paywall fires **once**, right after onboarding completes, with the `.onboarding` headline. | **NOT RUN** |
| 4.2 | Launch a second time after the intro has shown. | The intro does **not** appear again; the app opens straight to the shell (`paywall_intro_shown` is set). | **NOT RUN** |
| 4.3 | Fresh install, complete onboarding on a **key-less** build. | The intro does **not** fire (nothing can be sold), and `paywall_intro_shown` is **not** marked — so a later keyed build still gets to announce premium once. | **NOT RUN** |

---

## §5. The `PaywallSource` → headline mapping (Task 10)

Written by Task 10 from `PaywallViewModel.headlineKey(for:)`
(`Packages/Features/FeaturePaywall/Sources/FeaturePaywall/ui/PaywallViewModel.swift`) and the
`PaywallStrings` accessors. The automated half is the `PaywallViewModelTests` cases
`theTwoNonFeatureEntryPointsKeepTheGenericTitle` and `everyFeatureSourceGetsAHeadlineOfItsOwn`;
what no test can reach is the rendered headline on a real sheet for each entry point.

**The mapping.** `.onboarding` and `.settings` share the generic `paywall_title`; `.themes` →
`paywall_title_themes`; `.trends` → `paywall_title_trends`; `.aiSummary` →
`paywall_title_ai_summary`; `.doctorReport` → `paywall_title_doctor_report`; `.backup` →
`paywall_title_backup`. The trends and AI rows are **no-ops** until M10/M11 (their screens do not
exist yet), but the source mapping itself is testable from the entry points that do exist.

| # | Step | Expected | Status |
|---|------|----------|--------|
| 5.1 | Open the paywall from the More premium row. | The sheet's headline is the generic `paywall_title` ("Salus Premium"). | **NOT RUN** |
| 5.2 | Open the paywall from the More → theme dialog (premium row). | The sheet's headline is `paywall_title_themes` ("Premium temalara eriş"). | **NOT RUN** |
| 5.3 | Open the paywall from the doctor-report entry (More → doctor report, premium-gated). | The sheet's headline is `paywall_title_doctor_report` ("AI doktor raporuna eriş"). | **NOT RUN** |
| 5.4 | Open the paywall from the post-onboarding intro. | The sheet's headline is the generic `paywall_title` — the `.onboarding` source shares it with `.settings`. | **NOT RUN** |
| 5.5 | (M10/M11) Open the paywall from the trends and AI-summary rows. | The headline is `paywall_title_trends` / `paywall_title_ai_summary` respectively — **no-op until those milestones ship the rows**; the mapping is already wired. | **NOT RUN** |

---

## §6. The keyless build (Task 10)

Written by Task 10 from `App/SalusApp.swift` (the `Purchases.configure` guard) and
`RevenueCatPurchasesGateway` (`isConfigured`). The automated half is the keyless path in the
`IntroPaywallGateTests` and the repository's never-downgrade cases; what no test can reach is a
launched app with no RevenueCat key at all.

**How it works.** `SalusApp.init` reads `SALUS_REVENUECAT_API_KEY` (from the git-ignored
`App/Secrets.local.xcconfig`) and calls `Purchases.configure` only when it is non-blank. A blank
key leaves `Purchases.isConfigured == false`, so the gateway reports `isConfigured == false`, the
intro gate returns early, and `currentOffering()` yields nothing — the paywall surfaces
`offeringUnavailable`. The app runs fully free and never crashes.

| # | Step | Expected | Status |
|---|------|----------|--------|
| 6.1 | Build and launch with a blank `Secrets.local.xcconfig` (no RevenueCat key). | The app launches and runs **fully free**: no crash, no premium features unlocked, and the tab bar draws the classic palette. | **NOT RUN** |
| 6.2 | Open the paywall (More premium row) on the keyless build. | The body shows the `paywall_error_offering` text ("Planlar şu an yüklenemedi…") centred, with "Tekrar dene" and "Satın almaları geri yükle". No crash. | **NOT RUN** |
| 6.3 | Complete onboarding on the keyless build. | The intro paywall does **not** fire, and `paywall_intro_shown` is **not** marked. | **NOT RUN** |

---

## §7. The review-round regressions (post-review fixes)

Written after the branch review, from the three defects it turned up and the one the user hit
first. Each row is the *symptom* rather than the code, because these are the cases the automated
half structurally cannot reach: two are hit-testing and scene-phase behaviour, one is a fresh
clone, one is a plist the simulator resolves.

**7.1 — the Face ID loop** (`Packages/SalusCommon/Sources/SalusCommon/AppLockManager.swift`,
divergence 5). The Face ID sheet drives the scene `.active → .inactive → .active`, and the shell
forwards that last `.active` to `sceneDidBecomeActive()`. Ported literally, Kotlin's
`backgroundedAt == null ||` branch re-locked the app the instant its own prompt succeeded, so the
gate came back and fired the prompt again. Now only a scene that actually reached the background
may re-lock, and its stamp is spent once. The automated half is
`AppLockManagerTests`' two `.inactive`-round-trip cases; what they cannot reach is a real
`LAContext`.

**7.2 — the paywall host's touch layer** (`App/PaywallHost.swift`). `Color.clear` is hit-testable,
and the host is an unconditional full-bleed sibling at the top of `RootView`'s `ZStack`, so it
took every tap in the app until `.allowsHitTesting(false)` was added. There is no test target in
the app, so a tap is the only detector.

| # | Step | Expected | Status |
|---|------|----------|--------|
| 7.1 | More → turn the app lock on, authenticate the toggle's own prompt. | The toggle turns on. The lock gate does **not** appear behind it, and no second Face ID prompt fires. | **NOT RUN** |
| 7.2 | With the lock on, background the app for **more than** 30 s and return; authenticate. | The gate appears once, the prompt succeeds once, and the app's content is drawn. The prompt does **not** fire again. | **NOT RUN** |
| 7.3 | With the lock on and the session unlocked, pull down Control Centre (or take a call) and dismiss it. | Nothing happens: no gate, no prompt. The scene went `.inactive` and back, which is not leaving the app. | **NOT RUN** |
| 7.4 | With the lock on, background the app for **less than** 30 s and return, then wait a minute and pull Control Centre down and back. | Neither return re-locks. The short stay is judged once and cannot age into a re-lock. | **NOT RUN** |
| 7.5 | On any tab, tap a card, a tab-bar item and a toolbar button. | Every one responds. (Before the fix nothing did: the paywall host's transparent layer swallowed the whole window.) | **NOT RUN** |
| 7.6 | Open the paywall, dismiss it with the close button, then tap around the shell again. | The sheet closes and the shell is still fully interactive. | **NOT RUN** |
| 7.7 | In a **fresh clone** with no `App/Secrets.local.xcconfig`, run `xcodegen generate`. | It succeeds. `App/Secrets.xcconfig` is committed and `#include?`s the local file only if it exists. | **NOT RUN** |
| 7.8 | Build with a blank key but `SALUS_REVENUECAT_API_KEY` set in the scheme's environment. | The SDK **is** configured from the environment: the paywall loads real plans instead of `offeringUnavailable`. (Before the fix the always-present, empty Info.plist entry won and the environment was never read.) | **NOT RUN** |
