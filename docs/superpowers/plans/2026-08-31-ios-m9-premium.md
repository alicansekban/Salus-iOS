# iOS-M9 — Premium (RevenueCat, paywall, premium themes, restore) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. Executor subagents run per the `~/.config/opencode/opencode.jsonc` config (executor / executor-pro / executor-deepseek; model IDs verified at execution start with a no-op task). Compact plan: contracts and behaviour, not source code — the named Kotlin files are the spec. Read `CLAUDE.md`, `docs/ios-feature-template.md`, and the design spec `docs/superpowers/specs/2026-08-31-ios-m9-premium-design.md` before touching a task. Planned against `main` after iOS-M8 is fully merged.

**Goal:** Land the Premium layer — `SalusPremium` (the `:core:premium` twin over `purchases-ios`) + `FeaturePaywall` (the `:feature:paywall` twin) — and replace the M8 stand-ins (`FreeOnlyMorePremiumStatus`, `NoOpPaywallRequester`, two-state `MorePremiumStatusValue`, `FreeOnlyPremiumStatus`) with real `PremiumRepository`/`PaywallController` bindings, the paywall sheet, premium-theme entitlement, and restore purchases.

**Architecture:** `SalusPremium` owns the second SPM remote dependency `purchases-ios` (the allowlist's second of three), reached transitively by `FeaturePaywall` and the app — the GRDB-through-`SalusDatabase` pattern. `PremiumRepository` is the single source of entitlement (three-state `PremiumStatus`: free/premium/gracePeriod); `PaywallController` is the single gate to the paywall sheet; the shell mounts the sheet as a full-screen cover above the `TabView`. The M8 two-state stand-ins are deleted in the same tasks that land the real types. The Android `core/premium` + `feature/paywall` source files are the frozen 1:1 port target; their test tables are the drift detector.

**Tech Stack:** Swift 6 / SwiftUI, `purchases-ios` (RevenueCat, latest stable pinned `from:`), `swift-testing`.

**Spec:** `salus-ios/docs/superpowers/specs/2026-08-31-ios-m9-premium-design.md` — §2 (settled decisions D1–D8), §3 (open decisions O1–O3), §4 (architecture), §5 (data flow), §6 (error handling), §7 (testing), §8 (files), §9 (out of scope). `salus-android/docs/superpowers/specs/2026-08-19-premium-subscription-design.md` — the product spec. `salus-android/docs/ios-v1-plan.md` §10 (iOS-M9 row) + §7 (premium contract). `salus-android/docs/parity-ledger.md` S-3, S-15. **Do not modify Android code.**

## Global Constraints

- **Rulings (coordinator, 2026-08-31 — confirmed by the user):**
  1. **`purchases-ios` version:** latest stable at execution time, pinned `from: "<version>"` in `SalusPremium/Package.swift`. Record the pin in `README.md`'s Toolchain table alongside GRDB. The allowlist stays closed at three: GRDB + `purchases-ios` + `firebase-ios-sdk` (the last arrives with M10).
  2. **RevenueCat API key storage:** a git-ignored `Secrets.local.xcconfig` (the `.gitignore` already ignores `*.local.xcconfig` — no new entry needed) read by `project.yml` → injected as the build setting `SALUS_REVENUECAT_API_KEY` → read in `SalusApp` at launch and passed to `Purchases.configure` only when non-blank. A committed `Secrets.xcconfig.example` carries a blank value. The keyless-release guard mirrors Android's `isNotBlank` check: an unconfigured SDK never crashes, the paywall surfaces `offeringUnavailable`, the app runs fully free.
  3. **Store-name copy:** `paywall_renewal_note` is platform-mapped — iOS says "App Store" / "App Store üzerinden iptal edebilirsin" (TR). Recorded divergence (the M8 `apps.apple.com/account/subscriptions` precedent). Android keeps "Google Play".
  4. **`MorePremiumStatus` two-state protocol is deleted** (not kept as an adapter). `MoreViewModel` takes `any PremiumRepository` (or its `status: AsyncStream<PremiumStatus>`) directly. The M8 protocol existed only because the real repository did not; keeping it would add a mapping layer with no benefit. `MoreUiState.premiumStatus` becomes `PremiumStatus` (three-state). `latestPremiumStatus` becomes `PremiumStatus`, and the gate predicate changes from `== .entitled` to `.isEntitled`.
  5. **`HomePremiumStatus` protocol stays** (feature-local, `D-M7-t`); rebound to a real adapter over `PremiumRepository` (`isPremium: AsyncStream<Bool>` = `status.map { $0.isEntitled }`). The adapter lives in `FeatureHome/data/` (keeps `SalusPremium` out of Home's `domain/`). `FreeOnlyPremiumStatus` is deleted.
  6. **`PaywallSource` lifts into `SalusPremium`** (seven cases, Android-verbatim: `onboarding, settings, themes, trends, aiSummary, doctorReport, backup`). The feature-local `PaywallSource` in `MoreViewModel.swift` is deleted. `PaywallRequester` protocol is deleted — `MoreViewModel` takes `any PaywallController` directly. `NoOpPaywallRequester` is deleted.
  7. **`effectivePremiumTheme` lifts into `SalusPremium`** (three-state). The two-state `MoreScreenComponents.effectivePremiumTheme` is deleted.
  8. **The paywall is a full-screen cover above the `TabView`**, outside every `NavigationStack` (the M8 onboarding/lock gate z-order). `PaywallController.request != nil` drives it. Slide-up transition. Back gesture / swipe-down dismisses (Android `BackHandler`). The `PaywallHost` view lives in `App/` (shell code, like `AppLockScreen`).
  9. **`IntroPaywallGate` fires from a `.task` on `RootView`** after the onboarding gate resolves (Android `LaunchedEffect(Unit)` twin). It reads `preferences.userSettings`, waits for `onboardingCompleted`, checks `paywallIntroShown`, marks-shown-then-shows (process-death-safe). Only runs when `gateway.isConfigured` (keyless build: nothing shown, flag untouched).
  10. **Simulator and device QA are the user's job** (user ruling, carried from M7/M8): the executor runs zero simulator work. Every visual or interaction check is a numbered row in `scripts/m9-manual-qa.md`, written by the task's executor, executed only by the user. An executor step is `scripts/test-packages.sh <touched packages>` + `scripts/build-app.sh` + lint, full stop.
- **Recorded iOS divergences (write into the execution record, not silently):** (a) `paywall_renewal_note` says "App Store" not "Google Play" (ruling 3); (b) API key in `Secrets.local.xcconfig` not `local.properties`/`BuildConfig` (ruling 2); (c) `PurchaseHost` impl is `WindowPurchaseHost` (a `UIWindow` ref) not `ActivityPurchasesHost` (Android `Activity`); (d) `PaywallHost` is a `fullScreenCover` not an `AnimatedVisibility` overlay; (e) `HomePremiumStatus` stays feature-local with an adapter (ruling 5); (f) `MorePremiumStatus` two-state protocol deleted entirely (ruling 4); (g) `RevenueCatPurchasesGateway` has no direct unit test (no SDK in `swift test`) — covered by fake-backed tests + manual QA, exactly as Android covers it.
- **Never** reword any banned-stem copy; the `BannedHealthClaims` scanner runs repo-wide. `%1$s`→`%1$@` in `paywall_monthly_equivalent`. `Text(verbatim:)` for every resolved `Strings` accessor value passed to `Text` (the M7 `c726e22` rule).
- Strings: `FeaturePaywall` catalog = **30 keys** (the full Android table). Every key set is pinned by a literal key-set test (`StringCatalogParity`, tr source, both locales). `paywall_feature_backup` is kept in the catalog but **not sold** (the `PaywallFeatureListTest` invariant — 4 shipped features: ai_summary, doctor_report, trends, themes).
- `Calendar` rule: no new `Calendar` anywhere. `monthlyEquivalentOf` uses `NumberFormatter` + `Locale`, not `Calendar`.
- Colors: paywall plan cards use `theme.extendedColors` (`primaryContainer`/`onPrimaryContainer` for selected, `surfaceContainerLow`/`outlineVariant` for unselected). No new tokens.
- Every task: `scripts/test-packages.sh <touched packages>` + `scripts/build-app.sh` green before commit; SwiftFormat/SwiftLint clean (file 500, type 300, function 60, params 6); `scripts/clean.sh` after adding a file to a path dependency; `project.yml` + regenerated `pbxproj` in the same commit. Ported test files = Kotlin file name + `Tests.swift`; case names = Kotlin backtick names in camelCase. **No simulator or device work is ever an executor step.** Executors report: test names verified against the Kotlin files, every divergence from the Kotlin twin listed, nothing "fixed while passing" outside the task's files. Parallel tasks run in their own worktrees on `m9-t<N>` branches and are rebased onto `m9-premium` before review.
- Kotlin citations are re-derived with `grep -n` at execution time, not copied from this plan.

**Dependency graph:** T0 (branch + SalusPremium pure types incl. `PaywallSource`) → T1 (FeaturePaywall strings, needs T0's `PaywallSource`) ∥ T2 (SalusPremium gateway + repository, needs T0) → T3 (SalusPremium PaywallController, needs T0) ∥ T4 (FeaturePaywall UiState + ViewModel, needs T0 + T2 + T3) → T5 (FeaturePaywall IntroPaywallGate, needs T2 + T3) → T6 (FeaturePaywall PaywallSheet UI, needs T4 + T1) → T7 (FeatureSettings rebind — delete stand-ins, wire real PremiumRepository/PaywallController, needs T0 + T2 + T3) ∥ T8 (FeatureHome rebind — delete FreeOnlyPremiumStatus, wire adapter, needs T2) → T9 (App shell wiring — project.yml + Purchases.configure + PaywallHost + theme resolution + IntroPaywallGate, needs T2 + T3 + T6 + T7 + T8) → T10 (QA doc + parity ledger + docs, needs T9). Critical path: T0 → T2 → T4 → T6 → T9 → T10. T1 can start as soon as T0 merges; T7/T8 can parallelize with T5–T6.

---

### Task 0: Branch + `SalusPremium` pure types — `PremiumStatus`, `PaywallModels`, `PaywallSource`, `EffectiveTheme`

**Files:** Create `Packages/SalusPremium/Sources/SalusPremium/PremiumStatus.swift`, `PaywallModels.swift`, `PaywallSource.swift`, `EffectiveTheme.swift`; tests `Packages/SalusPremium/Tests/SalusPremiumTests/{PremiumStatusTests,EffectiveThemeTests,MonthlyEquivalentTests}.swift`. Modify `Packages/SalusPremium/Package.swift` (deps unchanged — `SalusModel` only for now; `purchases-ios` lands in T2).

**Android reference:** `core/premium/src/main/kotlin/.../PremiumStatus.kt` (29 lines), `PaywallModels.kt` (61 lines), `PaywallController.kt:8-19` (`PaywallSource` + `PaywallRequest`), `EffectiveTheme.kt` (14 lines). Tests: `PremiumStatusTest.kt` (4 cases), `EffectiveThemeTest.kt` (4 cases), `MonthlyEquivalentTest.kt` (5 cases).

**Interfaces:**
- Consumes: `SalusModel.PremiumTheme` (existing: `classic/ocean/sunset/forest`).
- Produces:
  - `public enum PremiumStatus: Sendable, Equatable { case free, premium, gracePeriod }`
  - `public extension PremiumStatus { var isEntitled: Bool { self != .free } }`
  - `public func premiumStatusOf(entitlementActive: Bool, hasBillingIssue: Bool) -> PremiumStatus`
  - `public struct CustomerSnapshot: Sendable, Equatable { public let entitlementActive: Bool; public let hasBillingIssue: Bool; public init(entitlementActive: Bool, hasBillingIssue: Bool) }`
  - `public enum PlanPeriod: Sendable, Equatable, CaseIterable { case monthly, sixMonth, annual }`
  - `public struct PremiumPlan: Sendable, Equatable { public let packageId: String; public let period: PlanPeriod; public let priceFormatted: String; public let monthlyEquivalent: String?; public let hasFreeTrial: Bool; public init(...) }`
  - `public struct PaywallOffering: Sendable, Equatable { public let plans: [PremiumPlan]; public init(plans: [PremiumPlan]) }`
  - `public enum PaywallSource: Sendable, Equatable, CaseIterable { case onboarding, settings, themes, trends, aiSummary, doctorReport, backup }` — moved here from T3 so T1 (strings) can import it without depending on the gateway task.
  - `public struct PaywallRequest: Sendable, Equatable { public let source: PaywallSource; public init(source: PaywallSource) }`
  - `public func monthlyEquivalentOf(amountMicros: Int64, currencyCode: String, period: PlanPeriod, locale: Locale = .current) -> String?`
  - `public func effectivePremiumTheme(_ status: PremiumStatus, _ selected: PremiumTheme) -> PremiumTheme`

- [ ] **Step 1: Create the branch and commit the plan.**
Run: `git checkout -b m9-premium` from `main` (M8 fully merged).
Commit: `docs(plan): iOS-M9 premium — RevenueCat, paywall, themes plan` with this file.

- [ ] **Step 2: Write `PremiumStatusTests.swift` (failing).**
Port the 4 `PremiumStatusTest` cases by name:
- `anActiveEntitlementWithABillingIssueIsAGracePeriod` — `premiumStatusOf(true, true) == .gracePeriod`
- `anActiveEntitlementWithoutABillingIssueIsPremium` — `premiumStatusOf(true, false) == .premium`
- `anInactiveEntitlementIsFreeWhateverTheBillingIssueFlagSays` — `premiumStatusOf(false, false) == .free` and `premiumStatusOf(false, true) == .free`
- `premiumAndGracePeriodAreEntitledFreeIsNot` — `PremiumStatus.premium.isEntitled == true`, `.gracePeriod.isEntitled == true`, `.free.isEntitled == false`

- [ ] **Step 3: Write `EffectiveThemeTests.swift` (failing).**
Port the 4 `EffectiveThemeTest` cases by name:
- `aPremiumUserKeepsTheThemeTheyPicked` — for every `PremiumTheme`, `effectivePremiumTheme(.premium, selected) == selected`
- `aGracePeriodUserKeepsTheThemeTheyPicked` — same for `.gracePeriod`
- `aFreeUserIsDrawnClassicWhateverTheStoredSelectionSays` — for every `PremiumTheme`, `effectivePremiumTheme(.free, selected) == .classic`
- `losingTheEntitlementFallsBackWithoutTouchingTheStoredSelection` — stored `.forest`: `.premium`→`.forest`, `.free`→`.classic` (the input is not mutated — Swift value types make this trivial, but assert the round-trip).

- [ ] **Step 4: Write `MonthlyEquivalentTests.swift` (failing).**
Port the 5 `MonthlyEquivalentTest` cases by name:
- `aMonthlyPlanHasNoMonthlyEquivalent` — `(29_990_000, "USD", .monthly, Locale(identifier: "en_US"))` → `nil`
- `anAnnualPriceIsDividedByTwelveAndFormattedInTheStoreCurrency` — `(359_880_000, "USD", .annual, Locale(identifier: "en_US"))` → `"$29.99"`
- `aSixMonthPriceIsDividedBySix` — `(179_940_000, "USD", .sixMonth, Locale(identifier: "en_US"))` → `"$29.99"`
- `theFormattedCurrencyFollowsTheRequestedLocale` — `(359_880_000, "TRY", .annual, Locale(identifier: "tr_TR"))` → `"₺29,99"`
- `anUnknownCurrencyCodeYieldsNoMonthlyEquivalent` — `(359_880_000, "not-a-currency", .annual, .current)` → `nil`

- [ ] **Step 5: Implement `PremiumStatus.swift`.**
`public enum PremiumStatus: Sendable, Equatable { case free, premium, gracePeriod }` with the `isEntitled` extension and `premiumStatusOf` — the `when {}` table: `entitlementActive && hasBillingIssue → .gracePeriod`; `entitlementActive → .premium`; `else → .free`. No raw values (Android has none).

- [ ] **Step 6: Implement `PaywallModels.swift`.**
`CustomerSnapshot`, `PlanPeriod`, `PremiumPlan`, `PaywallOffering` — straightforward structs/enums. `monthlyEquivalentOf`: `monthly → return nil`; `sixMonth → 6`; `annual → 12`; `perMonth = Double(amountMicros) / 1_000_000.0 / Double(months)`; `NumberFormatter()` with `numberStyle = .currency`, `currencyCode = currencyCode`, `locale = locale` → `formatter.string(from: NSNumber(value: perMonth))`; return `nil` on failure (the `runCatching.getOrNull` twin — a `do/catch` or `nil`-check on the formatter output).

- [ ] **Step 7: Implement `EffectiveTheme.swift`.**
`public func effectivePremiumTheme(_ status: PremiumStatus, _ selected: PremiumTheme) -> PremiumTheme { status.isEntitled ? selected : .classic }`

- [ ] **Step 8: Run tests.**
Run: `scripts/test-packages.sh SalusPremium`
Expected: PASS (all 13 cases).

- [ ] **Step 9: Lint + commit.**
Run: `swiftformat . && swiftlint --fix` then `swiftlint --strict` (repo-wide).
Commit: `feat(premium): PremiumStatus, paywall models and effective theme — the pure core`

---

### Task 1: `FeaturePaywall` strings — the 30-key catalog

**Files:** Modify `Packages/Features/FeaturePaywall/Sources/FeaturePaywall/FeaturePaywall.swift` (delete placeholder enum), create `Sources/FeaturePaywall/Resources/Localizable.xcstrings` (30 keys), `Sources/FeaturePaywall/PaywallStrings.swift`; test `Tests/FeaturePaywallTests/PaywallStringsTests.swift`. Modify `Package.swift` (`defaultLocalization: "tr"`, resources).

**Android reference:** `feature/paywall/src/main/res/values/strings.xml` (41 lines, 30 keys) + `values-en/strings.xml`. The full key list with TR + EN values is in the spec §4.3 and the design inventory.

**Interfaces:**
- Produces: `PaywallStrings` accessor enum with 30 keys. Formatted accessor `monthlyEquivalent(_ formatted: String) -> String` (reads `paywall_monthly_equivalent`, `%1$@`). Headline accessors per source. Plan-name accessors. Error accessors. URL accessors (`paywall_terms_url`, `paywall_privacy_url`).

- [ ] **Step 1: Write `PaywallStringsTests.swift` (failing).**
`assertSourceLanguage("tr")`, the literal 30-key pin, `assertEveryKeyIsLocalized` (both locales, no third). TR + EN value tables for every key. `%1$@` in `paywall_monthly_equivalent`. `BannedHealthClaims` repo-wide stays green. Divergence (a): `paywall_renewal_note` TR → "Abonelik, iptal edilmediği sürece dönem sonunda otomatik yenilenir. Dilediğin zaman App Store üzerinden iptal edebilirsin." EN → "The subscription renews automatically at the end of each period unless cancelled. You can cancel any time in the App Store." (ruling 3 — "App Store" not "Google Play").

- [ ] **Step 2: Create `Localizable.xcstrings` (30 keys).**
Copy every TR/EN value from the Android XML tables (re-verify each against `salus-android/feature/paywall/src/main/res/values{,-en}/strings.xml` with `grep -n` and report any mismatch as a finding). `%1$s`→`%1$@` in `paywall_monthly_equivalent`. Apply ruling 3 to `paywall_renewal_note`. The two URL keys (`paywall_terms_url`, `paywall_privacy_url`) carry the per-locale Google Sites URLs (shared, not store-pinned).

- [ ] **Step 3: Write `PaywallStrings.swift`.**
The accessor enum over `Bundle.module`, grouped by feature section. `headlineKey(for source: PaywallSource)` mapping — `import SalusPremium` (T0 produces `PaywallSource`; the `Package.swift` already lists `SalusPremium` as a dep). The mapping: `.onboarding`/`.settings` → `paywall_title`; `.themes` → `paywall_title_themes`; `.trends` → `paywall_title_trends`; `.aiSummary` → `paywall_title_ai_summary`; `.doctorReport` → `paywall_title_doctor_report`; `.backup` → `paywall_title_backup`. **T0 must merge before T1's commit** (the dep graph already enforces this — T0 ∥ T1 are independent for writing, but T1's commit compiles against T0's types).

- [ ] **Step 4: Modify `Package.swift`.**
Add `defaultLocalization: "tr"` to the `Package` initializer (the placeholder package has none). Confirm `Resources` path is picked up by the resource bundle (the catalog lives at `Sources/FeaturePaywall/Resources/Localizable.xcstrings`).

- [ ] **Step 5: Run tests + build.**
Run: `scripts/test-packages.sh FeaturePaywall` + `scripts/build-app.sh`
Expected: PASS.

- [ ] **Step 6: Lint + commit.**
Commit: `feat(paywall): the 30-key string catalog — TR + EN, App Store renewal note`

---

### Task 2: `SalusPremium` gateway + repository + `purchases-ios` dependency

**Files:** Modify `Packages/SalusPremium/Package.swift` (add `purchases-ios` remote dep). Create `Sources/SalusPremium/PurchasesGateway.swift`, `RevenueCatPurchasesGateway.swift`, `PremiumRepository.swift`, `WindowPurchaseHost.swift`; tests `Tests/SalusPremiumTests/{PremiumRepositoryImplTests,FakePurchasesGateway}.swift`.

**Android reference:** `PurchasesGateway.kt` (55 lines), `RevenueCatPurchasesGateway.kt` (178 lines), `PremiumRepository.kt` (53 lines). Test: `PremiumRepositoryImplTest.kt` (5 cases + `FakePurchasesGateway`).

**Interfaces:**
- Consumes: T0 (`PremiumStatus`, `CustomerSnapshot`, `PaywallModels`), `purchases-ios` SDK.
- Produces:
  - `public enum PurchaseOutcome: Sendable, Equatable { case success, cancelled, error(String) }`
  - `public protocol PurchaseHost: Sendable {}`
  - `public protocol PurchasesGateway: Sendable { var isConfigured: Bool { get }; var customerUpdates: AsyncStream<CustomerSnapshot> { get }; func currentCustomer() async -> CustomerSnapshot?; func currentOffering() async -> PaywallOffering?; func purchase(host: PurchaseHost, packageId: String) async -> PurchaseOutcome; func restore() async -> CustomerSnapshot }`
  - `public final class WindowPurchaseHost: PurchaseHost { public let window: UIWindow?; public init(window: UIWindow?) }` — the iOS `PurchaseHost` impl (divergence (c)). StoreKit's sheet is system-presented so the window ref is minimal.
  - `public final class RevenueCatPurchasesGateway: PurchasesGateway` — the adapter.
  - `public protocol PremiumRepository: Sendable { var status: AsyncStream<PremiumStatus> { get }; func refresh() async }`
  - `public final class PremiumRepositoryImpl: PremiumRepository` — `@MainActor @Observable`-equivalent; seeds `.free`; maps `customerUpdates` via `premiumStatusOf`; `refresh()` pulls `currentCustomer()`, updates only on non-nil.
  - `FakePurchasesGateway` (test fake, in `SalusPremiumTests`).

- [ ] **Step 1: Add `purchases-ios` to `Package.swift`.**
Add `.package(url: "https://github.com/RevenueCat/purchases-ios.git", from: "<latest stable>")` to `dependencies`, and `.product(name: "Purchases", package: "purchases-ios")` to the `SalusPremium` target's dependencies. **Verify the latest stable version** at execution time (check the RevenueCat releases). Record the pin. `SalusPremium` gains `.macOS(.v14)` if the host build needs it (RevenueCat may require it for `swift test` — verify and add only if needed, the GRDB-through-`SalusDatabase` precedent). Run `scripts/clean.sh`.

- [ ] **Step 2: Write `PremiumRepositoryImplTests.swift` (failing) + `FakePurchasesGateway.swift`.**
Port the 5 `PremiumRepositoryImplTest` cases by name:
- `theStatusStartsFreeBeforeTheGatewayReportsAnything`
- `theStatusFollowsEveryCustomerUpdateTheGatewayPublishes` (free → premium → gracePeriod → free)
- `refreshPullsTheCurrentCustomerFromTheGateway` (gracePeriod, `currentCustomerCalls == 1`)
- `refreshKeepsTheLastKnownStatusWhenTheStoreDoesNotAnswer` (premium stays after null)
- `aFailedRefreshNeverDowngradesAUserWhoIsInTheGracePeriod` (gracePeriod stays after two nulls, `currentCustomerCalls == 2`)

`FakePurchasesGateway`: `var customer: CustomerSnapshot?`, `currentCustomerCalls` counter, `MutableSharedFlow`-equivalent (`AsyncStream` with a `Continuation` the test yields into via `publish(_:)`), `isConfigured = true`, `currentOffering() = nil`, `purchase()` = `.cancelled`, `restore()` = `customer ?? FREE_SNAPSHOT`. The Android `backgroundScope` maps to the test's `Task` lifetime — the repository's collection runs in a `Task` cancelled at test end.

- [ ] **Step 3: Implement `PurchasesGateway.swift`.**
The protocol + `PurchaseOutcome` + `PurchaseHost` — straightforward. `PurchaseHost` is an empty `Sendable` protocol (opaque marker).

- [ ] **Step 4: Implement `PremiumRepository.swift`.**
`PremiumRepositoryImpl(gateway: PurchasesGateway)`: `@MainActor @Observable` with `private(set) var currentStatus: PremiumStatus = .free`; `var status: AsyncStream<PremiumStatus>` built as a cold stream that yields `currentStatus` on subscription and then continues; `init` launches a `Task` collecting `gateway.customerUpdates` → `currentStatus = premiumStatusOf(...)`; `refresh()` → `guard let snapshot = await gateway.currentCustomer() else { return }; currentStatus = premiumStatusOf(...)`. The `status` stream must re-yield on each `currentStatus` change — use an `AsyncStream` with a stored continuation (the `CurrentValueStream` shape from `MoreViewModel`, or a simpler `@Observable` + `AsyncStream` bridge). **The test reads `currentStatus` directly** (the Android test reads `status.value`); the stream is for consumers.

- [ ] **Step 5: Implement `WindowPurchaseHost.swift`.**
`public final class WindowPurchaseHost: PurchaseHost { public let window: UIWindow?; public init(window: UIWindow?) }` — minimal.

- [ ] **Step 6: Implement `RevenueCatPurchasesGateway.swift`.**
The adapter. `isConfigured` → `Purchases.isConfigured`. `customerUpdates` → `AsyncStream` wrapping `Purchases.shared.customerInfoStream` (the `callbackFlow` twin) + seed from `currentCustomer()`. `currentCustomer()` → unconfigured returns `FREE_SNAPSHOT`, else `await Purchases.shared.customerInfo()` + `toSnapshot()` with `safely`-style error handling (CancellationError rethrown). `currentOffering()` → `Purchases.shared.offerings()` → `current?.availablePackages` → `mapNotNull toPlan` → empty → nil. `purchase()` → unconfigured → `.error(NOT_CONFIGURED)`; find package by `identifier`; `Purchases.shared.purchase(package:)` → `.success`; `userCancelled` → `.cancelled`; else `.error(message)`. `restore()` → `Purchases.shared.restorePurchases()` → snapshot, fallback `FREE_SNAPSHOT`. Constants: `ENTITLEMENT_ID = "premium"`, `FREE_SNAPSHOT`, `NOT_CONFIGURED`, `PURCHASE_FAILED`. The `CustomerInfo.toSnapshot()` and `Package.toPlan()` helpers. **This file is not unit-tested** (divergence (g)) — covered by fake-backed tests + manual QA.

- [ ] **Step 7: Run tests.**
Run: `scripts/test-packages.sh SalusPremium`
Expected: PASS (all 5 cases). `RevenueCatPurchasesGateway` compiles against the SDK but is not exercised here.

- [ ] **Step 8: Build + lint + commit.**
Run: `scripts/build-app.sh` (verifies `purchases-ios` resolves and the app links `SalusPremium` transitively — **T9 links it formally, but the package must build now**).
Commit: `feat(premium): PurchasesGateway, RevenueCat adapter and PremiumRepository — the store seam`

---

### Task 3: `SalusPremium` `PaywallController`

**Files:** Create `Packages/SalusPremium/Sources/SalusPremium/PaywallController.swift`; test `Packages/SalusPremium/Tests/SalusPremiumTests/PaywallControllerTests.swift`.

**Android reference:** `PaywallController.kt` (51 lines; `PaywallSource`/`PaywallRequest` already ported in T0). Test: `PaywallControllerTest.kt` (4 cases).

**Interfaces:**
- Consumes: T0 (`PaywallSource`, `PaywallRequest`).
- Produces:
  - `@MainActor @Observable public final class PaywallController { public private(set) var request: PaywallRequest?; public func show(_ source: PaywallSource); public func dismiss() }`

- [ ] **Step 1: Write `PaywallControllerTests.swift` (failing).**
Port the 4 `PaywallControllerTest` cases by name:
- `thePaywallStartsClosed` — `request == nil`
- `showPublishesARequestCarryingTheSourceThatAskedForIt` — `show(.themes)` → `request == PaywallRequest(source: .themes)`
- `dismissClosesThePaywall` — after `show(.settings)`, `dismiss()` → nil
- `showingAgainWhileOpenReplacesTheSource` — `show(.onboarding)` then `show(.trends)` → `PaywallRequest(source: .trends)`

- [ ] **Step 2: Implement `PaywallController.swift`.**
`PaywallController`: `@MainActor @Observable`, `private(set) var request: PaywallRequest? = nil`, `show(_:)` sets `request = PaywallRequest(source: source)`, `dismiss()` sets `request = nil`. The `@Observable` macro makes `request` observable to the shell's `PaywallHost`. (`PaywallSource` and `PaywallRequest` are already defined in T0's `PaywallSource.swift` — import-free within the same package.)

- [ ] **Step 3: Run tests + lint + commit.**
Run: `scripts/test-packages.sh SalusPremium`
Commit: `feat(premium): PaywallController and PaywallSource — the single gate`

---

### Task 4: `FeaturePaywall` UiState + ViewModel + tests

**Files:** Create `Packages/Features/FeaturePaywall/Sources/FeaturePaywall/ui/{PaywallUiState,PaywallViewModel}.swift`, `PaywallModule.swift`; modify `Package.swift` if imports need it (deps already list `SalusPremium`). Tests `Tests/FeaturePaywallTests/{PaywallViewModelTests,FakePurchasesGateway,FakePremiumRepository}.swift`.

**Android reference:** `PaywallUiState.kt` (71 lines), `PaywallViewModel.kt` (149 lines), `PaywallModule.kt`. Test: `PaywallViewModelTest.kt` (21 cases — the largest table).

**Interfaces:**
- Consumes: T0 (`PremiumPlan`, `PlanPeriod`, `PaywallSource`, `PurchaseHost`, `PurchaseOutcome`), T2 (`PurchasesGateway`, `PremiumRepository`), T3 (`PaywallController`), T1 (`PaywallStrings`).
- Produces:
  - `public struct PaywallUiState: Equatable { isLoading: Bool = true; plans: [PremiumPlan] = []; selectedPackageId: String? = nil; isPurchasing: Bool = false; error: PaywallError? = nil; source: PaywallSource = .settings }`
  - `public enum PaywallError: Equatable, Sendable { case offeringUnavailable, purchaseFailed, restoreNoEntitlement }`
  - `public enum PaywallEvent: Sendable { case planSelected(String); case reload; case purchaseClicked(PurchaseHost); case restoreClicked; case dismissClicked }`
  - `internal func headlineKey(for source: PaywallSource) -> String` — the `headlineResFor` twin, mapping each source to its `paywall_title*` key.
  - `@MainActor @Observable public final class PaywallViewModel` — `init(gateway:premiumRepository:paywallController:)`, `state: PaywallUiState`, `onEvent(_:)`.
  - `PaywallModule` with `makePaywallViewModel()`.

- [ ] **Step 1: Write `PaywallViewModelTests.swift` (failing) + fakes.**
Port the 21 `PaywallViewModelTest` cases by name (the full list is in the design inventory §4.3):
- `initPreselectsTheAnnualPlan`
- `initFallsBackToTheFirstPlanWhenThereIsNoAnnualOne`
- `aMissingOfferingSurfacesOfferingUnavailable`
- `aSuccessfulPurchaseRefreshesTheEntitlementAndDismissesThePaywall`
- `aCancelledPurchaseLeavesThePaywallOpenWithoutAnError`
- `aFailedPurchaseSurfacesPurchaseFailed`
- `aSecondPurchaseClickIsIgnoredWhileOneIsInFlight` (with `purchaseGate`)
- `aRestoreThatFindsAnEntitlementRefreshesAndDismisses`
- `aRestoreThatFindsNothingSurfacesRestoreNoEntitlementAndStillRefreshes`
- `selectingAPlanClearsTheError`
- `aRestoreBlocksASecondRestoreWhileOneIsInFlight` (with `restoreGate`)
- `aRestoreInFlightBlocksAPurchaseClick`
- `aRestoreClearsTheErrorItStartsWith`
- `reloadRefetchesAnOfferingThatNeverArrived`
- `reloadClearsTheLastOpenSFailureButKeepsThePlansItHas`
- `dismissClosesThePaywall`
- `stateCarriesTheSourceThePaywallWasOpenedFrom`
- `reopeningFromAnotherFeatureReplacesTheSource`
- `dismissingKeepsTheLastSourceInsteadOfResettingTheHeadline`
- `theTwoNonFeatureEntryPointsKeepTheGenericTitle` (`headlineKey(.settings) == headlineKey(.onboarding)`)
- `everyFeatureSourceGetsAHeadlineOfItsOwn`

`FakePurchasesGateway`: `offering`, `customer`, `restoreSnapshot`, `purchaseOutcome` vars; `purchaseCalls`/`restoreCalls`/`offeringCalls`/`currentCustomerCalls` counters; `purchaseGate`/`restoreGate` as `CheckedContinuation`-based or `AsyncStream` gates (the Android `CompletableDeferred` twin). `FakePremiumRepository`: records `refreshCalls`, holds `status`. `FakePaywallController`: records `showSources`/`dismissCalls`, `request` property. `FakePurchaseHost`: a `PurchaseHost` no-op.

- [ ] **Step 2: Implement `PaywallUiState.swift`.**
The state struct, `PaywallError` enum, `PaywallEvent` enum, `headlineKey(for:)` — the switch mapping each `PaywallSource` to its `PaywallStrings` accessor. `[PremiumPlan]` (Swift Array — no `ImmutableList` equivalent needed).

- [ ] **Step 3: Implement `PaywallViewModel.swift`.**
`@MainActor @Observable`. `init` → `loadOffering()` + `observeSource()` (a `Task` collecting `paywallController.request`, writing `state.source` only when non-nil). `onEvent` dispatch: `planSelected` → copy `selectedPackageId` + clear `error`; `reload` → `reload()`; `purchaseClicked(host)` → `purchase(host)`; `restoreClicked` → `restore()`; `dismissClicked` → `paywallController.dismiss()`. `reload()` clears error; only `loadOffering()` if `plans.isEmpty && !isLoading`. `loadOffering()` sets `isLoading=true`; `plans = await gateway.currentOffering()?.plans ?? []`; empty → `isLoading=false, error=.offeringUnavailable`; else preselect annual-or-first, set `plans`, `selectedPackageId`, `error=nil`. `purchase(host)` guards `selectedPackageId` + `isPurchasing`; sets `isPurchasing=true`; on `.success` → `await premiumRepository.refresh()`, `isPurchasing=false`, `paywallController.dismiss()`; `.cancelled` → `isPurchasing=false`; `.error` → `isPurchasing=false, error=.purchaseFailed`. `restore()` guards `isPurchasing`; sets `isPurchasing=true, error=nil`; `snapshot = await gateway.restore()`; `await premiumRepository.refresh()` always; `isPurchasing=false`; `snapshot.entitlementActive` → `dismiss()` else `error=.restoreNoEntitlement`.

- [ ] **Step 4: Implement `PaywallModule.swift`.**
`PaywallModule` holding the gateway/repository/controller refs + `makePaywallViewModel()`. The module is constructed in `AppCompositionRoot` (T9).

- [ ] **Step 5: Run tests + lint + commit.**
Run: `scripts/test-packages.sh FeaturePaywall`
Commit: `feat(paywall): PaywallViewModel — offering, purchase, restore and the 21-case table`

---

### Task 5: `FeaturePaywall` `IntroPaywallGate`

**Files:** Create `Packages/Features/FeaturePaywall/Sources/FeaturePaywall/domain/IntroPaywallGate.swift`; test `Tests/FeaturePaywallTests/IntroPaywallGateTests.swift`.

**Android reference:** `IntroPaywallGate.kt` (47 lines). Test: `IntroPaywallGateTest.kt` (4 cases).

**Interfaces:**
- Consumes: T2 (`PaywallController`), T3 (`PaywallSource`), `SalusSettings.SalusPreferencesDataSource` (existing — `userSettings` stream + `setPaywallIntroShown`).
- Produces: `@MainActor final class IntroPaywallGate(preferences: SalusPreferencesDataSource, paywallController: PaywallController, isBillingConfigured: () -> Bool)` with `func run() async`.

- [ ] **Step 1: Write `IntroPaywallGateTests.swift` (failing).**
Port the 4 `IntroPaywallGateTest` cases by name:
- `waitsForOnboardingToCompleteThenShowsTheIntroAndMarksIt` — before onboarding: no paywall, not marked; after `onboardingCompleted=true`: marked, source `.onboarding`, gate job completed.
- `neverShowsOrReMarksTheIntroOnceItHasBeenShown` — `paywallIntroShown=true`: no paywall, not marked.
- `neverShowsOrMarksTheIntroWhenBillingIsNotConfigured` — `isBillingConfigured=false`: nothing shown/marked, flag untouched.
- `marksTheIntroShownBeforeOpeningThePaywall` — a `markShown` that records `paywallController.request == nil` sees `true` (paywall still closed when marked); then source `.onboarding`.

Fakes: `FakeSalusPreferencesDataSource` (or the existing `SalusTesting` fake if one exists — check `Packages/SalusTesting` for a preferences fake; the M8 `OnboardingViewModelTests` used one). `FakePaywallController` (from T4, or copy).

- [ ] **Step 2: Implement `IntroPaywallGate.swift`.**
`@MainActor final class IntroPaywallGate(preferences: SalusPreferencesDataSource, paywallController: PaywallController, isBillingConfigured: () -> Bool)`. `func run() async`: `guard isBillingConfigured() else { return }`; `let settings = await preferences.userSettings.first(where: { $0.onboardingCompleted })` (the `Flow.first { }` twin — `AsyncStream.first(where:)`); `guard !settings.paywallIntroShown else { return }`; `await preferences.setPaywallIntroShown(true)`; `paywallController.show(.onboarding)`. The mark-before-show ordering is the process-death-safety invariant.

- [ ] **Step 3: Run tests + lint + commit.**
Run: `scripts/test-packages.sh FeaturePaywall`
Commit: `feat(paywall): IntroPaywallGate — the one-time post-onboarding announcement`

---

### Task 6: `FeaturePaywall` `PaywallSheet` UI

**Files:** Create `Packages/Features/FeaturePaywall/Sources/FeaturePaywall/ui/{PaywallSheet,PaywallRoute}.swift`; test `Tests/FeaturePaywallTests/PaywallFeatureListTests.swift`. Modify `PaywallModule.swift` if the route needs a factory entry.

**Android reference:** `PaywallSheet.kt` (482 lines — the full UI). Test: `PaywallFeatureListTest.kt` (5 cases — the 4-shipped-features invariant).

**Interfaces:**
- Consumes: T4 (`PaywallViewModel`, `PaywallUiState`, `PaywallEvent`, `PaywallError`), T1 (`PaywallStrings`), T0 (`PremiumPlan`, `PlanPeriod`), `SalusUI` components (`SalusPillButton`, `SalusCard`, `SalusListItem`, etc.), `SalusDesignSystem` tokens.
- Produces: `PaywallRoute` (the `@MainActor struct PaywallRoute: View` that builds the VM from the module and renders `PaywallSheet`), `PaywallSheet` (stateless view), the `FeatureRows` constant (4 rows).

- [ ] **Step 1: Write `PaywallFeatureListTests.swift` (failing).**
Port the 5 `PaywallFeatureListTest` cases by name:
- `sellsExactlyTheFourFeaturesThatShipToday` — the declared `FeatureRows` labels == `[ai_summary, doctor_report, trends, themes]`
- `doesNotSellEncryptedBackupWhichDoesNotExist` — `backup` not in declared labels
- `keepsTheBackupStringSoTheRowCanReturnWithTheFeature` — `paywall_feature_backup` present in both locales of the catalog
- `everyShippedLabelIsTranslatedInBothLocales` — all four shipped labels in both locales
- `theRenderedListMatchesTheOneThatWasParsed` — `SHIPPED_FEATURES.count == FeatureRows.count`; icons all distinct

The test reads the `FeatureRows` declaration in `PaywallSheet.swift` by name (the Android source-parsing approach — the list is a code constant).

- [ ] **Step 2: Implement `PaywallSheet.swift`.**
The full-screen sheet UI. `FeatureRows` constant: 4 rows `(icon, labelKey)` in the Android order: `ai_summary, doctor_report, trends, themes` (SF Symbol equivalents for `AutoAwesome, Description, Insights, Palette` — use `systemName`: `"sparkles"`, `"doc.text"`, `"chart.xyaxis.line"`, `"paintpalette"`). `PlanDisplayOrder = [.annual, .sixMonth, .monthly]`. The sheet: `Surface`-equivalent (a `Color` background or `SalusCard`), close `IconButton` (`paywall_close`), loading → `ProgressView`, empty plans → `paywall_error_offering` text, else `PaywallContent` (headline via `headlineKey(state.source)` + `Text(verbatim:)`, subtitle, feature rows, plan cards in display order with "best value" badge on annual, monthly-equivalent line) + `PaywallActions` (CTA `paywall_cta_trial` if `hasFreeTrial` else `paywall_cta_subscribe`, enabled `!isPurchasing`; restore `TextButton`-twin; renewal note; `PolicyLinks` opening `paywall_terms_url`/`paywall_privacy_url`). All Salus tokens. `Text(verbatim:)` for resolved strings. `#Preview` code ships (for the user's later inspection — executor does not render-check).

- [ ] **Step 3: Implement `PaywallRoute.swift`.**
`@MainActor struct PaywallRoute: View` — builds the `PaywallViewModel` from `@Environment(\.paywallModule)` (an `@Entry` added in T9, or a closure-based factory), fires `onEvent(.reload)` in `.task`, renders `PaywallSheet(state:onEvent:onPurchase:onOpenUrl:)`. `onPurchase` passes a `WindowPurchaseHost(window: UIApplication.shared.connectedScenes...)` — the iOS `ActivityPurchasesHost` twin. `onOpenUrl` → `UIApplication.shared.open(URL(string:)!)` with `try?`-style guard.

- [ ] **Step 4: Run tests + build + lint + commit.**
Run: `scripts/test-packages.sh FeaturePaywall` + `scripts/build-app.sh`
Write `scripts/m9-manual-qa.md` §1 rows (the paywall sheet: loading state, plan cards, best-value badge, monthly equivalent, CTA trial/subscribe, restore, renewal note, policy links, close) — written, never run.
Commit: `feat(paywall): the paywall sheet — plans, features, actions and policy links`

---

### Task 7: `FeatureSettings` rebind — delete stand-ins, wire real `PremiumRepository` + `PaywallController`

**Files:** Modify `Packages/Features/FeatureSettings/Sources/FeatureSettings/ui/more/{MoreViewModel,MoreUiState,MoreScreen,MoreScreenComponents}.swift`, `domain/MorePremiumStatus.swift` (delete), `data/FreeOnlyMorePremiumStatus.swift` (delete), `SettingsModule.swift`; tests `Tests/FeatureSettingsTests/{MoreViewModelTests,MoreFakes,MorePremiumStandInTests}.swift` (delete the stand-in test, update the VM tests).

**Android reference:** `feature/settings/.../ui/more/MoreViewModel.kt` (the real Kotlin reads `PremiumRepository.status` and `PaywallController`).

**Interfaces:**
- Consumes: T2 (`PremiumRepository`, `PremiumStatus`), T3 (`PaywallController`, `PaywallSource`), T0 (`effectivePremiumTheme`).
- Produces: updated `MoreViewModel` (takes `any PremiumRepository` + `any PaywallController`), updated `MoreUiState` (`premiumStatus: PremiumStatus`), deleted `MorePremiumStatus`/`MorePremiumStatusValue`/`FreeOnlyMorePremiumStatus`/`PaywallRequester`/feature-local `PaywallSource`.

- [ ] **Step 1: Delete the stand-ins.**
Delete `Packages/Features/FeatureSettings/Sources/FeatureSettings/domain/MorePremiumStatus.swift`, `data/FreeOnlyMorePremiumStatus.swift`, `Tests/FeatureSettingsTests/MorePremiumStandInTests.swift`. In `MoreViewModel.swift`: delete the `PaywallRequester` protocol (lines 62–70) and the feature-local `PaywallSource` enum (lines 75–79). In `MoreScreenComponents.swift`: delete the `effectivePremiumTheme(_:_:)` function (lines 105–109).

- [ ] **Step 2: Update `MoreUiState.swift`.**
`premiumStatus: PremiumStatus` (was `MorePremiumStatusValue`). `import SalusPremium`.

- [ ] **Step 3: Update `MoreViewModel.swift`.**
- `import SalusPremium`.
- Replace `private let premiumStatus: any MorePremiumStatus` with `private let premiumRepository: any PremiumRepository`.
- Replace `private let paywallRequester: any PaywallRequester` with `private let paywallController: any PaywallController`.
- `latestPremiumStatus: PremiumStatus = .free` (was `MorePremiumStatusValue`).
- The `init` signature: `(profileRepository:premiumRepository:preferences:localeController:paywallController:)`.
- `restartObservation()`: the `secondaryState` fold reads `premiumRepository.status` (the `AsyncStream<PremiumStatus>`) instead of `premiumStatus.status`. `SecondaryState.premiumStatus: PremiumStatus`.
- Gate predicates: `latestPremiumStatus == .entitled` → `latestPremiumStatus.isEntitled` (in `.colorThemeSelected`, `.premiumClicked`, `.doctorReportClicked`).
- `paywallRequester.show(.themes)` → `paywallController.show(.themes)` (etc. — the `PaywallSource` cases are now `SalusPremium.PaywallSource`).
- `effectivePremiumTheme` calls in `MoreScreenComponents`/`MoreScreen` → `SalusPremium.effectivePremiumTheme(_:_)`.

- [ ] **Step 4: Update `MoreScreen.swift` + `MoreScreenComponents.swift`.**
`import SalusPremium`. The premium row subtitle: `state.premiumStatus.isEntitled` (was `== .entitled`). The color-theme subtitle: `effectivePremiumTheme(state.premiumStatus, state.premiumTheme)` from `SalusPremium`.

- [ ] **Step 5: Update `SettingsModule.swift`.**
`makeMoreViewModel` / `makeSettingsModule` signature: `premiumRepository: any PremiumRepository` + `paywallController: any PaywallController` (was `premiumStatus: any MorePremiumStatus` + `paywallRequester: any PaywallRequester`).

- [ ] **Step 6: Update `MoreViewModelTests.swift` + fakes.**
- `FakeMorePremiumStatus` → `FakePremiumRepository` (or use the `SalusPremiumTests` fake shape — but it's in a different test target; create a `FeatureSettingsTests`-local fake over `PremiumRepository` that emits `PremiumStatus` values).
- `FakePaywallRequester` → `FakePaywallController` over `PaywallController` (or a protocol-implementation fake). The gate-routing assertions: `== .entitled` → `.isEntitled`. The entitled-branch tests (deferred in M8 with a note) now run against `.premium`/`.gracePeriod`/`.free`. The `openUrl`/`openDoctorReport` effect assertions become real.
- Port the Android `MoreViewModelTest` cases that were deferred — the entitled branches. Verify case names against `salus-android/feature/settings/src/test/.../MoreViewModelTest.kt` with `grep -n`.

- [ ] **Step 7: Run tests + build + lint + commit.**
Run: `scripts/test-packages.sh FeatureSettings SalusPremium` + `scripts/build-app.sh`
Commit: `refactor(settings): bind real PremiumRepository and PaywallController; delete the M8 stand-ins`

---

### Task 8: `FeatureHome` rebind — delete `FreeOnlyPremiumStatus`, wire adapter

**Files:** Modify `Packages/Features/FeatureHome/Sources/FeatureHome/HomeModule.swift`, `data/FreeOnlyPremiumStatus.swift` (delete), `domain/repository/HomePremiumStatus.swift` (keep protocol, add adapter), `ui/HomeViewModel.swift` (if it references the fake); tests `Tests/FeatureHomeTests/HomeViewModelTests.swift`.

**Android reference:** Home's `HomePremiumStatus` is feature-local (`D-M7-t`); the adapter maps `PremiumRepository.status` → `isPremium: AsyncStream<Bool>`.

**Interfaces:**
- Consumes: T2 (`PremiumRepository`, `PremiumStatus`).
- Produces: `FeatureHome/data/PremiumRepositoryHomePremiumStatus.swift` (the adapter), updated `HomeModule` (takes `premiumRepository`), deleted `FreeOnlyPremiumStatus.swift`.

- [ ] **Step 1: Create the adapter.**
`Packages/Features/FeatureHome/Sources/FeatureHome/data/PremiumRepositoryHomePremiumStatus.swift`: `@MainActor final class PremiumRepositoryHomePremiumStatus: HomePremiumStatus` — `init(premiumRepository: any PremiumRepository)`, `var isPremium: AsyncStream<Bool> { premiumRepository.status.map { $0.isEntitled } }` (the `SalusPremium` import is needed in `data/`, not `domain/` — the `D-M7-t` boundary holds: Home's `domain/` stays `SalusPremium`-free). `import SalusPremium` in this `data/` file only.

- [ ] **Step 2: Delete `FreeOnlyPremiumStatus.swift`.**
Delete `Packages/Features/FeatureHome/Sources/FeatureHome/data/FreeOnlyPremiumStatus.swift`.

- [ ] **Step 3: Update `HomeModule.swift`.**
`makeHomeModule` signature gains `premiumRepository: any PremiumRepository` (or the adapter is built in `AppCompositionRoot` and passed in as `homePremiumStatus: any HomePremiumStatus` — **prefer the latter** to keep `SalusPremium` out of `HomeModule`'s import list; the composition root builds the adapter). `FreeOnlyPremiumStatus()` → `PremiumRepositoryHomePremiumStatus(premiumRepository:)` built in T9. **For this task, `HomeModule`'s signature changes to take `homePremiumStatus: any HomePremiumStatus`** (it already does — check `HomeModule.swift:75`; if `FreeOnlyPremiumStatus()` is constructed *inside* `HomeModule`, move the construction to the composition root).

- [ ] **Step 4: Update `HomeViewModelTests.swift`.**
`FakeHomePremiumStatus` gains a `.premium` path (the M8 fake only emitted `false`). The existing premium-gated arm asserts against `true`. No new cases unless the Android `HomeViewModelTest` has premium-specific ones — verify with `grep -n`.

- [ ] **Step 5: Run tests + build + lint + commit.**
Run: `scripts/test-packages.sh FeatureHome SalusPremium` + `scripts/build-app.sh`
Commit: `refactor(home): bind HomePremiumStatus to PremiumRepository; delete FreeOnlyPremiumStatus`

---

### Task 9: App shell wiring — `project.yml`, `Purchases.configure`, `PaywallHost`, theme resolution, `IntroPaywallGate`

**Files:** Modify `App/SalusApp.swift`, `App/RootView.swift`, `App/AppCompositionRoot.swift`, `App/AppCompositionRoot+Modules.swift`, `project.yml` (+ regenerated `pbxproj`), `README.md` (Toolchain table). Create `App/PaywallHost.swift`, `App/Secrets.xcconfig.example`, `Packages/Features/FeaturePaywall/Sources/FeaturePaywall/PaywallModule.swift` (`@Entry` — if not done in T4).

**Android reference:** `SalusApp.kt` (PaywallHost wiring lines 138–226, IntroPaywallGate lines 106–107), `SalusApplication.onCreate` (Purchases.configure).

**Interfaces:**
- Consumes: T2 (`PremiumRepository`, `RevenueCatPurchasesGateway`, `PurchasesGateway`), T3 (`PaywallController`), T5 (`IntroPaywallGate`), T6 (`PaywallRoute`), T7 (updated `SettingsModule`), T8 (updated `HomeModule`).
- Produces: the wired shell.

- [ ] **Step 1: `Secrets.xcconfig.example` + `project.yml`.**
Create `App/Secrets.xcconfig.example` with `SALUS_REVENUECAT_API_KEY =` (blank). The `.gitignore` already ignores `*.local.xcconfig` — the user creates `Secrets.local.xcconfig` locally with their key. In `project.yml`: add a `configFiles` entry for the `Debug`/`Release` configs pointing to `Secrets.local.xcconfig` (optional — the build setting can also be set via `settings.base` with `$(SALUS_REVENUECAT_API_KEY)` and the xcconfig included at the project level). Add `SalusPremium` and `FeaturePaywall` to the `packages:` block and the app target's `dependencies:`. Add `SALUS_REVENCECAT_API_KEY` to `settings.base` as `$(SALUS_REVENUECAT_API_KEY)` (reads from the xcconfig; blank if absent). Run `xcodegen generate`, commit `project.yml` + `pbxproj` together.

- [ ] **Step 2: `AppCompositionRoot.swift` — new singletons.**
Add `let premiumRepository: any PremiumRepository`, `let paywallController: PaywallController`, `let paywallModule: PaywallModule`, `let introPaywallGate: IntroPaywallGate`. In `makeInfrastructure` or `makeFeatureModules`: build `RevenueCatPurchasesGateway()`, `PremiumRepositoryImpl(gateway:)`, `PaywallController()`. The `makeSettingsModule` call: replace `premiumStatus: FreeOnlyMorePremiumStatus()` + `paywallRequester: NoOpPaywallRequester()` with `premiumRepository: premiumRepository` + `paywallController: paywallController`. The `makeHomeModule` call: replace `FreeOnlyPremiumStatus()` with `PremiumRepositoryHomePremiumStatus(premiumRepository:)` (built in the root, passed as `homePremiumStatus:`). Build `IntroPaywallGate(preferences:paywallController:isBillingConfigured: { gateway.isConfigured })`. Delete `App/NoOpPaywallRequester.swift`.

- [ ] **Step 3: `SalusApp.swift` — `Purchases.configure`.**
In `init()`, before `AppCompositionRoot()`: read `SALUS_REVENUECAT_API_KEY` from `Bundle.main.infoDictionary` or the build setting (`ProcessInfo.processInfo.environment["SALUS_REVENUECAT_API_KEY"]` — verify the xcconfig path). `if !apiKey.isEmpty { Purchases.configure(PurchasesConfiguration.Builder(withAPIKey: apiKey).build()) }`. The composition root builds the gateway, which reads `Purchases.isConfigured`. **Ordering: configure before the root builds the gateway.**

- [ ] **Step 4: `App/PaywallHost.swift` — the full-screen cover.**
`@MainActor struct PaywallHost: View` — reads `@Environment(AppCompositionRoot.self)`, observes `root.paywallController.request`, presents `PaywallRoute()` as a `fullScreenCover(isPresented: binding)` when `request != nil`. Slide-up transition (`.transition(.move(edge: .bottom))` or the `fullScreenCover`'s default). `PaywallRoute` gets `root.paywallModule` via `.environment`.

- [ ] **Step 5: `RootView.swift` — mount `PaywallHost` + theme resolution + `IntroPaywallGate`.**
- Mount `PaywallHost()` above the `TabView` (in the `ZStack` / overlay layer, outside every `NavigationStack`).
- Theme resolution: replace `premiumTheme: .classic` (line 91) with a derived value from `root.premiumRepository` — observe `premiumRepository.status` + `preferences.userSettings.premiumTheme` → `effectivePremiumTheme(status, premiumTheme)`. This requires a `@State premiumTheme: PremiumTheme = .classic` mirrored from `userSettings` (the same `.task` loop that mirrors `themeMode`/`secureScreenEnabled`/`onboardingCompleted`) and a `@State premiumStatus: PremiumStatus = .free` mirrored from `premiumRepository.status`. The `theme` computed property uses `effectivePremiumTheme(premiumStatus, premiumTheme)`.
- `IntroPaywallGate`: a `.task` on `RootView` (or on the `RootGates` overlay) that calls `await root.introPaywallGate.run()` — after the onboarding gate has resolved (the gate's `userSettings.first { $0.onboardingCompleted }` handles the ordering).
- The `onOpenDoctorReport`/`onOpenTrends` TODO(M10/M11) no-ops **stay** — M9 does not build those screens.

- [ ] **Step 6: `README.md` Toolchain table.**
Add the `purchases-ios` pin (version + the `SalusPremium/Package.swift` location).

- [ ] **Step 7: Run tests + build + lint + commit.**
Run: `scripts/test-packages.sh SalusPremium FeaturePaywall FeatureSettings FeatureHome SalusModel SalusSettings` + `scripts/build-app.sh` + `scripts/ci.sh` (full 5/5).
Write `scripts/m9-manual-qa.md` §2 rows (keyless build: app launches, paywall surfaces offeringUnavailable, no crash; shell: PaywallHost appears above TabView, slide-up, close; theme: premium theme unlocks on entitlement, lapses to classic on free; IntroPaywallGate: fires after onboarding once, not on second launch) — written, never run.
Commit: `feat(app): wire PremiumRepository, PaywallController and the paywall host; configure RevenueCat`

---

### Task 10: QA doc + parity ledger + docs

**Files:** Finalize `scripts/m9-manual-qa.md`; modify `salus-android/docs/parity-ledger.md` (the one Android-repo write — `D-M8-b` resolved, S-15 repository-gate wired), `salus-ios/CLAUDE.md` (if the allowlist line needs the `purchases-ios` arrival recorded — the CLAUDE.md already names it as arriving with M9; verify and add a line if needed).

- [ ] **Step 1: Finalize `scripts/m9-manual-qa.md`.**
Consolidate the §1 (paywall sheet) + §2 (shell) rows from T6/T9, plus:
- §3: sandbox purchase → premium themes unlock; cancel → grace → lapse; restore with/without entitlement; offline (cached entitlement stays).
- §4: intro paywall after onboarding (first launch) + not on second launch.
- §5: each `PaywallSource` opens the right headline (themes/settings/doctor-report; trends+ai rows are no-ops until M10/M11 but the paywall source mapping is testable).
- §6: keyless build (blank `Secrets.local.xcconfig`) → app runs free, paywall shows offeringUnavailable.

- [ ] **Step 2: Parity ledger update.**
In `salus-android/docs/parity-ledger.md`: mark `D-M8-b` resolved (two-state stand-in → full `PremiumStatus` at M9 — delivered). S-15 (premium check never only in UI) — the `PremiumRepository` is in place; the AI/report repository re-checks land with M10. Add the recorded iOS divergences (a)–(g) from the global constraints. **This is the only Android-repo write; it is a docs commit, local-only, never pushed unless the user says so.**

- [ ] **Step 3: `salus-ios/CLAUDE.md` — verify the allowlist line.**
The CLAUDE.md already says `purchases-ios` arrives with M9. Verify the tree now has exactly two remote SPM deps (GRDB + `purchases-ios`) and the allowlist line is accurate. Add a line recording the `purchases-ios` arrival if the current text only mentions GRDB as "the one remote dep today" — update "exactly one" to "exactly two" with the M9 arrival.

- [ ] **Step 4: Final `scripts/ci.sh` + commit.**
Run: `scripts/ci.sh` (full 5/5 green — the entry ticket).
Commit: `docs(m9): QA matrix, parity ledger and the allowlist update` (iOS side). The Android parity-ledger commit is separate, local-only.

---

## Verification (milestone done-when)

- All ported test tables green: `SalusPremium` 13 cases (T0) + 5 (T2) + 4 (T3) = 22; `FeaturePaywall` 30-key strings (T1) + 21 VM cases (T4) + 4 gate cases (T5) + 5 feature-list cases (T6) = 60; updated `MoreViewModelTests` (T7) + `HomeViewModelTests` (T8).
- `scripts/ci.sh` 5/5 green; `scripts/build-app.sh` green with `purchases-ios` resolved.
- A keyless build (blank `Secrets.local.xcconfig`) launches, runs fully free, paywall surfaces `offeringUnavailable` — never crashes.
- Manual QA matrix (`scripts/m9-manual-qa.md`) executed by the user.
- Parity ledger: `D-M8-b` resolved, S-15 repository-gate wired.