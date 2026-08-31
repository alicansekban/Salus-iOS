# iOS-M9 — Premium (RevenueCat, paywall, premium themes, restore) Design

**Date:** 2026-08-31 · **Path:** architectural (new subsystem, second SPM dependency `purchases-ios`)
**Parity target:** `salus-android` `core/premium` + `feature/paywall` on `main` (RevenueCat `10.17.0` Android; iOS SDK `purchases-ios` latest stable, pinned `from:`).
**Spec authority:** `salus-android/docs/superpowers/specs/2026-08-19-premium-subscription-design.md` (approved), `salus-android/docs/ios-v1-plan.md` §10 (iOS-M9 row) + §7 (premium contract), `salus-android/docs/parity-ledger.md` rows S-3 / S-15.
**Status:** draft — awaiting user review before the implementation plan is written.

## 1. Goal

Land the Premium layer the M8 stand-ins promised. Concretely:

1. **`SalusPremium`** becomes the real `:core:premium` twin: `PremiumStatus` (three-state, grace included), `premiumStatusOf`, `PurchasesGateway` + `RevenueCatPurchasesGateway` over `purchases-ios`, `PremiumRepository`, `PaywallController`, `PaywallSource`, `CustomerSnapshot`, `PremiumPlan`, `PaywallOffering`, `PurchaseOutcome`, `PlanPeriod`, `monthlyEquivalentOf`, `effectivePremiumTheme`.
2. **`FeaturePaywall`** becomes the real `:feature:paywall` twin: `PaywallViewModel`, `PaywallUiState`/`Event`/`PaywallError`, `PaywallSheet` (+ header/content/actions/components), `IntroPaywallGate`, the paywall string catalog (30 keys).
3. **The M8 stand-ins are deleted** and replaced by real bindings: `FreeOnlyMorePremiumStatus`, `MorePremiumStatus`/`MorePremiumStatusValue` (two-state), feature-local `PaywallRequester`/`PaywallSource`, `NoOpPaywallRequester`, `FreeOnlyPremiumStatus` (Home), and the `effectivePremiumTheme(_:_:)` two-state helper in `MoreScreenComponents`.
4. **The shell mounts the paywall** as an overlay sheet and resolves the effective theme from entitlement.
5. **The `purchases-ios` SPM dependency** is added (the allowlist's second entry, closed at three; GRDB + `purchases-ios` + `firebase-ios-sdk`).

Nothing else ships in M9. The deferred premium features (AI summary M10, doctor report M10, trends M11) keep their M8 no-op callbacks in `RootView`; M9 only makes **the gate and the paywall** real. The premium themes feature is the one entitlement effect that lands fully now, because the tokens already exist (`PremiumTheme.accentPalette`).

## 2. Settled decisions (from the port contract — not re-litigated)

| # | Decision | Source |
|---|---|---|
| D1 | **`purchases-ios` is the second SPM dep**, pinned `from: "<latest stable>"` at execution time. The allowlist stays closed at three. Declared in `SalusPremium/Package.swift` (the owner) and reached transitively by `FeaturePaywall` and the app, exactly as GRDB is reached through `SalusDatabase`. | iOS `CLAUDE.md` (allowlist) |
| D2 | **Premium is per-platform; no entitlement state in backups.** §6.3, S-3. No accounts, no cross-store transfer. | `ios-v1-plan.md` §6.3 |
| D3 | **The premium check is never only in the UI.** `PremiumRepository.status` is the single source; every future premium-gated repository (AI M10, report M10, backup M12) re-checks entitlement before the call. M9 wires the repository and the gate; the future repositories consume it. | parity ledger S-15 |
| D4 | **The paywall is a modal sheet, not a navigation destination.** Android's `PaywallHost` is an `AnimatedVisibility` overlay above the `Scaffold`; the iOS twin is a `.sheet`-style full-screen cover above the `TabView`, outside every `NavigationStack` (the same z-order the M8 onboarding/lock gates use). Back gesture dismisses (Android `BackHandler`). | premium spec §3, `PaywallHost.kt` |
| D5 | **`PaywallController` is a shared singleton** (app-scoped, not screen-scoped) — a deletion pops back to the list and destroys the detail VM, so the controller must outlive the screen that opened it. Android: Koin `single`; iOS: a `let` in `AppCompositionRoot`. | premium spec §3, `PremiumModule.kt` |
| D6 | **`IntroPaywallGate` marks-shown-then-shows, process-death-safe**, and only runs when billing is configured. Android `IntroPaywallGate.run()` verbatim. | `IntroPaywallGate.kt:39-46` |
| D7 | **One free AI summary per install is M10's concern**, not M9's. M9 delivers the gate, the paywall, the repository, and the premium-theme effect. The `freeSummaryUsed` / `ai_calls_*` keys already exist in `SalusSettings` untouched. | `ios-v1-plan.md` §7, S-14 |
| D8 | **Grace period is entitled.** `PremiumStatus.isEntitled == (self != .free)`. M8 folded grace into `.entitled`; M9 restores the third state but keeps "entitled" as the gate predicate. The More row subtitle and the effective theme both key off `isEntitled`, exactly as Android's `EffectiveTheme.kt` does. | `PremiumStatus.kt`, `EffectiveTheme.kt` |

## 3. Open decisions (resolved at planning time, with the user)

| # | Question | Resolution |
|---|---|---|
| O1 | `purchases-ios` version pin | **Latest stable at execution time**, pinned `from:` in `SalusPremium/Package.swift`. Verified against the RevenueCat release feed. The pin is recorded in `README.md`'s Toolchain table alongside GRDB. |
| O2 | RevenueCat API key storage (Android: `local.properties` → `BuildConfig`) | **A git-ignored `Secrets.xcconfig`** read by `project.yml` → injected as a build setting (`SALUS_REVENUECAT_API_KEY`) → read in `SalusApp` at launch and passed to `Purchases.configure` only when non-blank. The keyless-release guard mirrors Android's `isNotBlank` check: an unconfigured SDK never crashes and the paywall surfaces `OFFERING_UNAVAILABLE`. `Secrets.xcconfig` is git-ignored (`.gitignore` entry added this milestone); a `Secrets.xcconfig.example` is committed with a blank value. |
| O3 | Store-name copy in `paywall_renewal_note` (Android EN: "cancel in Google Play") | **Platform-mapped: iOS says "App Store" / "App Store üzerinden iptal edebilirsin".** Recorded divergence (the M8 subscriptions-URL precedent, `apps.apple.com/account/subscriptions`). Android keeps "Google Play". Both store-listing texts state subscriptions are tied to the respective store. |

## 4. Architecture

### 4.1 Module graph delta

Two packages go from empty placeholders to real, and link into the app:

```
SalusPremium   (← :core:premium)   deps: SalusModel, purchases-ios (remote)
FeaturePaywall (← :feature:paywall) deps: SalusModel, SalusCommon, SalusDesignSystem, SalusUI,
                                    SalusNavigation, SalusSettings, SalusPremium
App             links: SalusPremium, FeaturePaywall (new in project.yml)
```

`SalusPremium` owns the `purchases-ios` `.package(url:)` line — the **only** second remote dep in the tree. `FeaturePaywall` and the app reach it transitively (the GRDB-through-`SalusDatabase` pattern). `project.yml`'s `packages:` block gains the two local packages; the app target's `dependencies:` gains `product: SalusPremium` and `product: FeaturePaywall`. No new entitlements (in-app purchase is a StoreKit capability configured in App Store Connect, not a code-side entitlement file entry; the existing time-sensitive notifications entitlement stays).

### 4.2 `SalusPremium` — public API (the `:core:premium` twin)

Every type is the 1:1 port of its Kotlin file. Tests are the 1:1 port of the Kotlin test tables (the drift detector).

- **`PremiumStatus`** (`PremiumStatus.swift`): `public enum PremiumStatus: Sendable, Equatable { case free, premium, gracePeriod }`; `public extension PremiumStatus { var isEntitled: Bool { self != .free } }`; `public func premiumStatusOf(entitlementActive: Bool, hasBillingIssue: Bool) -> PremiumStatus` (the `when {}` table). No raw values (Android has none; nothing persists this enum).
- **`PaywallModels.swift`**: `CustomerSnapshot(entitlementActive: Bool, hasBillingIssue: Bool)`; `PlanPeriod { monthly, sixMonth, annual }`; `PremiumPlan(packageId: String, period: PlanPeriod, priceFormatted: String, monthlyEquivalent: String?, hasFreeTrial: Bool)`; `PaywallOffering(plans: [PremiumPlan])`; `monthlyEquivalentOf(amountMicros: Int64, currencyCode: String, period: PlanPeriod, locale: Locale = .current) -> String?` — `NumberFormatter(currency)` twin, `nil` for monthly, divide-by-6/12 for the others; `tr-TR` reproduces `₺29,99`.
- **`PurchasesGateway.swift`**: `PurchaseOutcome { success, cancelled, error(String) }`; `protocol PurchaseHost: Sendable {}` (opaque — iOS impl is a thin window/scene wrapper, not an `Activity`); `protocol PurchasesGateway: Sendable { var isConfigured: Bool { get }; var customerUpdates: AsyncStream<CustomerSnapshot> { get }; func currentCustomer() async -> CustomerSnapshot?; func currentOffering() async -> PaywallOffering?; func purchase(host: PurchaseHost, packageId: String) async -> PurchaseOutcome; func restore() async -> CustomerSnapshot }`.
- **`RevenueCatPurchasesGateway.swift`**: the adapter. `isConfigured` → `Purchases.isConfigured`; `customerUpdates` → `AsyncStream` wrapping `Purchases.shared.customerInfoStream` (the `callbackFlow` twin) plus a seed from `currentCustomer()`; `currentCustomer()` → unconfigured returns `FREE_SNAPSHOT`, else `await` + `toSnapshot()` with `safely`-style `do/catch` (CancellationError rethrown); `currentOffering()` → maps `Offerings.current.availablePackages` to `[PremiumPlan]` via `Package.toPlan()` (packageType → `monthly`/`sixMonth`/`annual`), empty → `nil`; `purchase()` → unconfigured → `.error(NOT_CONFIGURED)`, find package, `Purchases.shared.purchase(package:)` → `.success`, `userCancelled` → `.cancelled`, else `.error(message)`; `restore()` → `Purchases.shared.restorePurchases()` → snapshot, fallback `FREE_SNAPSHOT`. Constants `ENTITLEMENT_ID = "premium"`, `FREE_SNAPSHOT`, `NOT_CONFIGURED`, `PURCHASE_FAILED`. The `PurchaseHost` impl is `WindowPurchaseHost` (a thin struct carrying a `UIWindow`/`UIScene` reference if RevenueCat needs it; the StoreKit sheet is system-presented so this is minimal).
- **`PremiumRepository.swift`**: `protocol PremiumRepository: Sendable { var status: AsyncStream<PremiumStatus> { get }; func refresh() async }`; `PremiumRepositoryImpl(gateway: PurchasesGateway)`: holds `@MainActor @Observable`-equivalent state, seeds `.free`, maps `customerUpdates` via `premiumStatusOf`, `refresh()` pulls `currentCustomer()` and updates only on non-nil (null = store didn't answer, status untouched — the grace-period-safety test).
- **`PaywallController.swift`**: `PaywallSource { onboarding, settings, themes, trends, aiSummary, doctorReport, backup }` (Android-verbatim case set; `backup` reserved, no caller); `PaywallRequest(source: PaywallSource)`; `@MainActor @Observable PaywallController { var request: PaywallRequest?; func show(_ source: PaywallSource); func dismiss() }` (replaces an open request, the Android `value =` semantics).
- **`EffectiveTheme.swift`**: `public func effectivePremiumTheme(_ status: PremiumStatus, _ selected: PremiumTheme) -> PremiumTheme { status.isEntitled ? selected : .classic }`. Deletes the two-state `MoreScreenComponents.effectivePremiumTheme`.

**Tests** (`SalusPremiumTests`): port `PremiumStatusTest` (4 cases), `EffectiveThemeTest` (4), `MonthlyEquivalentTest` (5, incl. `tr-TR`), `PremiumRepositoryImplTest` (5, with `FakePurchasesGateway`), `PaywallControllerTest` (4). The gateway's RevenueCat-facing adapter is **not** unit-tested against the real SDK (no sandbox in `swift test`) — it is covered by the fake-backed repository tests + the manual QA matrix. This mirrors Android exactly (`RevenueCatPurchasesGateway` has no direct test; `PremiumRepositoryImplTest` uses `FakePurchasesGateway`).

### 4.3 `FeaturePaywall` — the `:feature:paywall` twin

- **`PaywallStrings.swift`** + `Localizable.xcstrings` (30 keys): the full Android table, TR + EN. `%1$s`→`%1$@` in `paywall_monthly_equivalent`. `paywall_renewal_note` EN → "App Store" (O3); TR → "App Store üzerinden iptal edebilirsin". `paywall_terms_url` / `paywall_privacy_url` are the existing per-locale Google Sites URLs (shared, not store-pinned). `PaywallStringsTests` pins the 30-key set, source-language `tr`, both locales, and `BannedHealthClaims` repo-wide stays green (the `PaywallStringsTest` twin).
- **`IntroPaywallGate.swift`**: `@MainActor final class IntroPaywallGate(preferences: SalusPreferencesDataSource, paywallController: PaywallController, isBillingConfigured: () -> Bool)`; `func run() async` — Android verbatim: `guard isBillingConfigured() else { return }`; `let settings = await preferences.userSettings.first(where: { $0.onboardingCompleted }); guard !settings.paywallIntroShown else { return }; await preferences.setPaywallIntroShown(true); paywallController.show(.onboarding)`. (`markShown`-before-`show` is the `await preferences…` ordering.) `SalusPreferencesDataSource` already exposes `setPaywallIntroShown` and the `paywallIntroShown` field (verified — `SettingsKeys.swift:28`, `SalusPreferencesDataSource.swift:97`).
- **`PaywallUiState.swift`**: `PaywallUiState(isLoading: Bool = true, plans: [PremiumPlan] = [], selectedPackageId: String? = nil, isPurchasing: Bool = false, error: PaywallError? = nil, source: PaywallSource = .settings)`; `PaywallError { offeringUnavailable, purchaseFailed, restoreNoEntitlement }`; `PaywallEvent { planSelected(String), reload, purchaseClicked(PurchaseHost), restoreClicked, dismissClicked }`; `headlineKey(for source:)` — the `headlineResFor` twin, mapping each source to its `paywall_title*` key.
- **`PaywallViewModel.swift`**: `@MainActor @Observable PaywallViewModel(gateway: PurchasesGateway, premiumRepository: PremiumRepository, paywallController: PaywallController)`; `init` → `loadOffering()` + observe `paywallController.request` (writes `source` only when non-nil). Events: `planSelected` (clears error), `reload` (only refetch if `plans.isEmpty && !isLoading`), `purchaseClicked` (guards `isPurchasing`; `.success` → `await premiumRepository.refresh()`, `paywallController.dismiss()`; `.cancelled` → no-op; `.error` → `error = .purchaseFailed`), `restoreClicked` (guards; `await gateway.restore()`, `await premiumRepository.refresh()` always; entitlement active → dismiss, else `restoreNoEntitlement`), `dismissClicked` → `paywallController.dismiss()`.
- **`PaywallSheet.swift`**: the full-screen sheet UI — close button, loading spinner, `offeringUnavailable` empty state, `PaywallContent` (headline + subtitle + 4 feature rows in the Android order: ai_summary, doctor_report, trends, themes — `backup` is **not** sold, the `PaywallFeatureListTest` invariant), plan cards in display order `[annual, sixMonth, monthly]` with the "best value" badge on annual, monthly-equivalent line, `PaywallActions` (CTA `paywall_cta_trial` if `hasFreeTrial` else `paywall_cta_subscribe`, restore button, renewal note, policy links). All Salus tokens; `Text(verbatim:)` for resolved strings (the M7 `c726e22` rule).
- **`PaywallModule.swift`**: `PaywallModule` holding `makePaywallViewModel()`; wired from `AppCompositionRoot+Modules.swift`.

**Tests** (`FeaturePaywallTests`): port `IntroPaywallGateTest` (4), `PaywallViewModelTest` (21 — the largest table; the fake-gateway + `purchaseGate`/`restoreGate` concurrency guards port as `CheckedContinuation`-based or `AsyncStream`-gate fakes), `PaywallFeatureListTest` (the 4-shipped-features invariant — on iOS this reads the `FeatureRows` declaration in `PaywallSheet.swift` source, the same source-parsing approach Android uses, because the list is a code constant not a resource). `PaywallStringsTest` (banned-claims + parity).

### 4.4 Stand-in deletion + re-binding

The M8 stand-ins are deleted **in the same task** that lands the real type, so the tree never has both:

| Delete | Replace with |
|---|---|
| `FeatureSettings/data/FreeOnlyMorePremiumStatus.swift` | `SalusPremium.PremiumRepository` injected into `MoreViewModel`; a small `MorePremiumStatusAdapter` over `premiumRepository.status` maps `PremiumStatus` → `MorePremiumStatusValue` **only if the More protocol is kept** — see below |
| `FeatureSettings/domain/MorePremiumStatus.swift` (`MorePremiumStatusValue` two-state) | **Decision: delete the two-state protocol entirely.** `MoreViewModel` takes `any PremiumRepository` (or a `@MainActor` stream of `PremiumStatus`) directly. The M8 protocol existed only because the real repository did not; keeping it would add a second mapping layer with no benefit. `MoreUiState.premiumStatus: PremiumStatus` (three-state). |
| `FeatureSettings/ui/more/MoreViewModel.swift` `PaywallRequester`/`PaywallSource` | `SalusPremium.PaywallController` (injected) + `SalusPremium.PaywallSource`. The feature-local definitions are deleted. |
| `App/NoOpPaywallRequester.swift` | Deleted; `AppCompositionRoot` binds the real `PaywallController`. |
| `FeatureHome/data/FreeOnlyPremiumStatus.swift` + `HomePremiumStatus` protocol | **Decision: keep `HomePremiumStatus` as a protocol but bind it to a real adapter** over `PremiumRepository` (`HomePremiumStatus` → `isPremium: AsyncStream<Bool>` = `premiumRepository.status.map { $0.isEntitled }`). Home stays feature-isolated (no `SalusPremium` import in Home's `domain/` — the adapter lives in `App` or in `FeatureHome/data/`). `FreeOnlyPremiumStatus` is deleted. This preserves the `D-M7-t` feature-local-protocol rule and the Home domain layer's `SalusPremium`-free boundary. |
| `MoreScreenComponents.effectivePremiumTheme(_:_:)` (two-state) | `SalusPremium.effectivePremiumTheme(_:_)` (three-state). |
| `RootView.swift:91 premiumTheme: .classic` pin | Resolved `effectivePremiumTheme(premiumRepository.status, stored)` — a derived value the shell observes. |

### 4.5 Shell wiring (`App`)

- **`AppCompositionRoot.swift`**: new `let premiumRepository: PremiumRepository`, `let paywallController: PaywallController`, `let paywallModule: PaywallModule`. The `makeSettingsModule` call loses `FreeOnlyMorePremiumStatus()` / `NoOpPaywallRequester()` and gains `premiumRepository`, `paywallController`. A `let homePremiumStatus: HomePremiumStatus` adapter is built over `premiumRepository` and injected into `makeHomeModule` (replacing `FreeOnlyPremiumStatus()`).
- **`SalusApp.swift`**: at launch, `if !apiKey.isBlank { Purchases.configure(PurchasesConfiguration.Builder(apiKey: apiKey).build()) }` before the composition root builds the gateway. The API key reads from the `SALUS_REVENUECAT_API_KEY` build setting (O2). The `IntroPaywallGate.run()` fires from a `.task` on `RootView` (the Android `LaunchedEffect(Unit)` twin) — after the onboarding gate has resolved, so a first-launch user sees onboarding then the intro paywall.
- **`RootView.swift`**: mounts `PaywallHost` above the `TabView` (a `fullScreenCover` driven by `paywallController.request != nil`, with the slide-up transition). Resolves the effective theme from `premiumRepository.status` + `stored premiumTheme` instead of pinning `.classic`. The `onOpenDoctorReport`/`onOpenTrends` TODO(M10/M11) no-ops **stay** — M9 does not build those screens; it only makes their paywall gate real (a free user tapping the row opens the paywall, an entitled user hits the no-op which will be wired in M10/M11).
- **`AppCompositionRoot+Modules.swift`**: `makePaywallModule` and the grown `makeHomeModule` / `makeSettingsModule` signatures.
- **`project.yml`**: `Secrets.xcconfig` include (git-ignored), `SALUS_REVENUECAT_API_KEY` build setting, `SalusPremium` + `FeaturePaywall` in `packages:` and the app `dependencies:`. Regenerated `pbxproj` committed together.
- **`Secrets.xcconfig.example`** committed (blank value); `.gitignore` gains `Secrets.xcconfig`.

### 4.6 Effective theme + More row subtitles

`MoreScreen`'s premium row subtitle and the color-theme dialog subtitle both read `PremiumStatus.isEntitled`:
- Premium/grace → `settings_premium_active` / the selected theme name.
- Free → `settings_premium_promo` / "Classic" (the `effectivePremiumTheme` fallback).

The `colorThemeSelected` gate in `MoreViewModel`: entitled → persist + close; free → close + `paywallController.show(.themes)`. The `premiumClicked` gate: entitled → `openUrl(appStoreSubscriptionsUrl)`; free → `show(.settings)`. `doctorReportClicked`: entitled → `openDoctorReport` (the M10 no-op callback); free → `show(.doctorReport)`. All three are the M8 gate logic with `PaywallController` swapped in for `PaywallRequester` and `PremiumStatus` for `MorePremiumStatusValue`.

## 5. Data flow

```
Purchases.shared (purchases-ios)
   │ customerInfoStream + restorePurchases + purchase(package)
   ▼
RevenueCatPurchasesGateway ──customerUpdates──▶ PremiumRepositoryImpl ──status──▶ [MoreViewModel, HomeViewModel, RootView theme resolver]
   │ currentOffering / purchase / restore                                        │
   ▼                                                                             ▼
PaywallViewModel ◀──request/source── PaywallController ◀──show(.themes)/.settings/...── MoreViewModel / IntroPaywallGate
   │ purchaseClicked / restoreClicked
   ▼
gateway.purchase → on success: premiumRepository.refresh() + paywallController.dismiss()
```

The repository is the single source of entitlement. The paywall controller is the single channel for "open the paywall". The two never cross directly: the paywall VM reads `request` for the source, calls `gateway` for the purchase, and calls `premiumRepository.refresh()` + `paywallController.dismiss()` on success — exactly the Android `PaywallViewModel` chain.

## 6. Error handling

- **Unconfigured SDK** (blank API key, keyless release build): `isConfigured == false`; `customerUpdates` emits `FREE_SNAPSHOT` once; `currentOffering()` → `nil`; `purchase()` → `.error(NOT_CONFIGURED)`. The paywall surfaces `offeringUnavailable`; the app runs fully free, never crashes. This is the Android `isNotBlank` guard's twin (O2).
- **Store didn't answer** (`currentCustomer()` → `nil`): `refresh()` leaves status untouched — a grace-period user stays in grace. `PremiumRepositoryImplTest` pins this.
- **User cancelled purchase**: `.cancelled` → no error, paywall stays open, `isPurchasing` resets.
- **Restore found nothing**: `restoreNoEntitlement` error shown, `refresh()` still runs (the counter-increment test).
- **Concurrent purchase/restore**: `isPurchasing` guard + the `purchaseGate`/`restoreGate` fake tests (Android's `purchaseCalls == 1` invariant).

## 7. Testing

- **`SalusPremiumTests`**: 5 ported tables (22 cases total) over `FakePurchasesGateway` (the Android fake's twin — `currentCustomerCalls`/`purchaseCalls`/`restoreCalls` counters, gateable `purchase`/`restore`). `RevenueCatPurchasesGateway` itself is **not** unit-tested (no SDK in `swift test`) — covered by fake-backed tests + manual QA.
- **`FeaturePaywallTests`**: `IntroPaywallGateTest` (4), `PaywallViewModelTest` (21), `PaywallFeatureListTest` (5 — the 4-shipped-features invariant), `PaywallStringsTest` (parity + banned-claims).
- **`FeatureSettingsTests`**: `MoreViewModelTests` updated — the entitled-branch tests (deferred with a note in M8) now run against a fake `PremiumRepository` flipping `.premium`/`.gracePeriod`/`.free`. The gate-routing assertions stay; the `openUrl`/`openDoctorReport` effect assertions become real.
- **`FeatureHomeTests`**: `HomeViewModelTests` — `FakeHomePremiumStatus` gains a `.premium` path (the M8 fake only emitted `false`); the existing premium-gated arm asserts against `true`.
- **`SalusModelTests`**: no change (`PremiumTheme` cases/raw values already pinned).
- **`SalusSettingsTests`**: no change (`paywall_intro_shown` key already pinned).
- **Repo-wide**: `BannedHealthClaims` stays green; `scripts/ci.sh` 5/5; `scripts/test-packages.sh SalusPremium FeaturePaywall FeatureSettings FeatureHome SalusModel SalusSettings` + `scripts/build-app.sh` green per task.
- **Manual QA** (`scripts/m9-manual-qa.md`, written by executors, run by the user): sandbox purchase, cancel, refund, grace period, restore with/without entitlement, keyless build, offline (cached entitlement stays), intro paywall after onboarding, paywall from each source (themes/settings/doctor-report/the future trends+ai rows), premium theme switch + lapse-to-classic.

## 8. Files touched (summary)

**New (SalusPremium):** `PremiumStatus.swift`, `PaywallModels.swift`, `PurchasesGateway.swift`, `RevenueCatPurchasesGateway.swift`, `PremiumRepository.swift`, `PaywallController.swift`, `EffectiveTheme.swift`, `Package.swift` (deps + `purchases-ios`), tests × 5, `WindowPurchaseHost.swift`.
**New (FeaturePaywall):** `PaywallStrings.swift`, `Localizable.xcstrings`, `IntroPaywallGate.swift`, `PaywallUiState.swift`, `PaywallViewModel.swift`, `PaywallSheet.swift`, `PaywallModule.swift`, `Package.swift` (deps), tests × 4.
**New (App):** `PaywallHost.swift` (the full-screen cover mount), `HomePremiumStatusAdapter.swift` (over `PremiumRepository`), `Secrets.xcconfig.example`, `scripts/m9-manual-qa.md`.
**Modified:** `App/SalusApp.swift` (Purchases.configure), `App/RootView.swift` (PaywallHost + theme resolution), `App/AppCompositionRoot.swift` (+ `.gitignore`), `App/AppCompositionRoot+Modules.swift`, `project.yml` (+ regenerated pbxproj), `README.md` (Toolchain table), `Packages/Features/FeatureSettings/.../MoreViewModel.swift` (real `PaywallController`/`PremiumStatus`), `MoreUiState.swift`, `MoreScreen.swift`, `MoreScreenComponents.swift` (delete local `effectivePremiumTheme`), `Packages/Features/FeatureHome/.../HomeModule.swift` (real adapter), `Packages/Features/FeatureSettings/SettingsModule.swift` (signature).
**Deleted:** `FreeOnlyMorePremiumStatus.swift`, `MorePremiumStatus.swift`, `App/NoOpPaywallRequester.swift`, `FeatureHome/data/FreeOnlyPremiumStatus.swift` (the `HomePremiumStatus` protocol stays, rebound).

## 9. Out of scope (M10+)

- AI summary screen, doctor report PDF, the `AiSummaryRepository` gating order (M10).
- Advanced trends screen (M11).
- Encrypted backup (M12; `PaywallSource.backup` reserved, no caller).
- The `freeSummaryUsed` / `ai_calls_*` counter logic (M10).
- App Store Connect product configuration (a manual step in the QA matrix, not code).
- Cross-platform entitlement transfer (§6.3 decided against; P-7 deferred).

## 10. Verification (milestone done-when)

- All ported test tables green (`SalusPremium` 22 cases, `FeaturePaywall` 34 cases, updated `MoreViewModel`/`HomeViewModel` tests).
- `scripts/ci.sh` 5/5 green; `scripts/build-app.sh` green with `purchases-ios` resolved.
- A keyless build (blank `Secrets.xcconfig`) launches, runs fully free, and the paywall surfaces `offeringUnavailable` — never crashes.
- Manual QA matrix (`scripts/m9-manual-qa.md`) executed by the user: sandbox purchase → premium themes unlock; cancel → grace → lapse; restore with/without entitlement; intro paywall after onboarding; each `PaywallSource` opens the right headline.
- Parity ledger updated: `D-M8-b` resolved, S-15's repository-gate wired (the AI/report repositories land in M10 but the `PremiumRepository` they'll re-check is in place).