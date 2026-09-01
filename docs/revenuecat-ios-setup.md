# iOS RevenueCat + App Store Connect Setup Guide

The iOS app's `SalusPremium` package, `SalusApp.configureRevenueCat()`, `Secrets.xcconfig` seam, and `RevenueCatPurchasesGateway` are all shipped and tested (M9). What remains is the **external dashboard configuration** — App Store Connect products and the RevenueCat iOS app + offering — plus the one local file that carries the key. This guide is the sequence.

## Prerequisites

- An Apple Developer account with the `com.alicansekban.salus` App ID (already created for M0).
- A RevenueCat account (the same one the Android app is on).
- Android reference: `salus-android/local.properties` holds `salus.revenuecat.apiKey=test_gjePwySSFbNnmNJwVlinZzFFBTa`. The iOS app needs its own key on the same RevenueCat project.

## Step 1 — App Store Connect: subscription group + products

1. Go to **App Store Connect → My Apps → Salus → Monetization → Subscriptions**.
2. Create a **Subscription Group** (name: "Premium").
3. Add three subscription products:

| Reference Name | Product ID | Subscription Duration | Price (TRY) |
|---|---|---|---|
| Premium Monthly | `com.alicansekban.salus.premium.monthly` | 1 Month | ₺49,99 |
| Premium 6-Month | `com.alicansekban.salus.premium.sixmonth` | 6 Months | ₺249,99 |
| Premium Annual | `com.alicansekban.salus.premium.annual` | 1 Year | ₺499,99 |

4. For each product:
   - Set the price tier (TRY).
   - Add a **localized description** in Turkish and English.
   - Upload a **subscription icon** (1024×1024).
   - Set the **free trial** on the annual product (7 days) if the paywall's "7 gün ücretsiz dene" CTA should fire.
5. Set the **App Store Localizations** for the subscription group (TR + EN).
6. Save and wait for Apple to propagate (usually a few minutes in sandbox).

> **Product IDs must match exactly what RevenueCat expects.** The Android `Play Store` product IDs differ (`premium_monthly`, `premium_six_month`, `premium_annual`), but RevenueCat maps both platforms to the same `premium` entitlement — the iOS product IDs are what you enter in RevenueCat's iOS packages.

## Step 2 — RevenueCat: add the iOS app

1. Go to **RevenueCat Dashboard → Project Settings → Apps**.
2. Click **+ New App → iOS**.
3. Fill in:
   - **App name:** Salus
   - **Bundle ID:** `com.alicansekban.salus`
   - **App Store Connect API Key:** (optional, for better sandbox testing — RevenueCat can sync products automatically)
4. Save. RevenueCat generates an **iOS App-Specific API Key** starting with `appl_`.
5. Copy that key — it goes into `Secrets.local.xcconfig`.

## Step 3 — RevenueCat: configure products and entitlement

1. Go to **Product Catalog → Products**.
2. Add the three iOS product IDs from Step 1:
   - `com.alicansekban.salus.premium.monthly` — App: iOS
   - `com.alicansekban.salus.premium.sixmonth` — App: iOS
   - `com.alicansekban.salus.premium.annual` — App: iOS
3. Go to **Entitlements**. The `premium` entitlement already exists (Android uses it). Attach all three iOS products to it, alongside the existing Android products.
4. Go to **Offerings → Current Offering**. Add the three iOS products as packages:
   - `$rc_monthly` → iOS monthly product
   - `$rc_six_month` → iOS six-month product
   - `$rc_annual` → iOS annual product
5. Save the offering. It should now contain both Android and iOS packages.

## Step 4 — Local: set the API key

```bash
printf 'SALUS_REVENUECAT_API_KEY = appl_YOUR_KEY_HERE\n' > App/Secrets.local.xcconfig
```

The file is git-ignored (`.gitignore: *.local.xcconfig`). The committed `App/Secrets.xcconfig` has `#include? "Secrets.local.xcconfig"` which tolerates its absence — so a fresh clone without the key still builds and runs (the app stays fully free, no crash).

## Step 5 — Regenerate the Xcode project and build

```bash
cd salus-ios
xcodegen generate
scripts/build-app.sh
```

## Step 6 — Sandbox purchase test

1. Create a **Sandbox Tester** in App Store Connect → Users → Sandbox → Testers.
2. On the simulator: Settings → Developer → Sandbox Account → sign in with the sandbox tester.
3. Build and run the app (`scripts/build-app.sh` then run in Xcode).
4. Walk the `scripts/m9-manual-qa.md` matrix:
   - §1.3: paywall shows three plan cards (annual first, with free trial badge + "7 gün ücretsiz dene" CTA).
   - §1.7: tapping the CTA opens the store sheet, purchase succeeds, paywall dismisses.
   - §3.1: premium theme unlocks immediately after purchase.
   - §3.2: cancel subscription in sandbox → grace period → theme lapses back to classic.
   - §3.3: restore purchases finds the entitlement.
   - §3.4: restore with no entitlement shows the restore error.
   - §3.5: offline relaunch keeps the cached entitlement.
5. Walk `scripts/m11-manual-qa.md` §1 (free user locked preview) and §2 (premium user four cards).

## Step 7 — Commit nothing

The key never enters git. The only committed change from this guide is this file and the QA matrices — the code is already on `main`.

## Reference

- Android `local.properties`: `salus.revenuecat.apiKey=test_gjePwySSFbNnmNJwVlinZzFFBTa` (Android key, not usable on iOS)
- iOS seam: `App/Secrets.xcconfig` (committed, blank default) + `App/Secrets.local.xcconfig` (git-ignored, the real key)
- iOS gateway: `Packages/SalusPremium/Sources/SalusPremium/RevenueCatPurchasesGateway.swift`
- iOS configuration: `App/SalusApp.swift:59` — `configureRevenueCat()`
- Entitlement ID: `"premium"` (hardcoded in `RevenueCatPurchasesGateway.swift:117`)
- QA matrix: `scripts/m9-manual-qa.md` (premium lifecycle) + `scripts/m11-manual-qa.md` (trends)