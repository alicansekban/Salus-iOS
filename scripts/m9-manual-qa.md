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
