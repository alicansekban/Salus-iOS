# iOS-M8 — Settings hub, onboarding, app lock, localization + a11y Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. Executor subagents run per the ~/.config/opencode/opencode.jsonc config (executor / executor-pro / executor-deepseek; model IDs verified at execution start with a no-op task). Compact plan: contracts and behaviour, not source code — the named Kotlin files are the spec. Read `CLAUDE.md`, `docs/ios-feature-template.md` and the research inventories `docs/research/2026-08-30-m8-settings-feature-inventory.md` + `docs/research/2026-08-30-m8-applock-onboarding-inventory.md` (committed, unlike M7's git-ignored `.superpowers/sdd/` research; they hold every signature, string key and test-case name this plan cites) before touching a task. Planned against `main` at `aa696e5` — M7 fully merged, final review wave included.

**Goal:** Build the More hub (`FeatureSettings`: MoreRoute/Screen + Profile editor + About + `SettingsPreferences` + the language controller — 20 More + 8 Profile Kotlin cases green), the onboarding flow (`FeatureOnboarding`: 8 steps, Sex hard gate, finish-writes-profile-then-flag — 6 UiState + 7 ViewModel cases green), the app lock (`AppLockManager` + `AppLockScreen` + LAContext prompt — 6 cases green) with the gate wiring in `SalusApp`/`RootView` (onboarding outermost, lock beneath, splash-hold until DataStore answers), the iOS §6.2 secure screen (always-on switcher blur + `secure_screen_enabled` masking toggle), and the M8-wide chores: the last string catalogs (settings 74 + onboarding 54 + app 3 owed keys), the in-app language switch (`AppLanguage` + locale controller), `NSFaceIDUsageDescription`, and the spec's VoiceOver + Dynamic Type pass at the largest sizes with Turkish strings.

**Architecture:** Settings: builders-not-shape again — `SettingsStrings` grows from 15 to 87 keys, `ReminderHealth` stays; M8 adds `ui/more/`, `ui/profile/`, `ui/about/`, `domain/SettingsPreferences` (thin adapter over `SalusPreferencesDataSource` — the store already exposes all four setters, the M7 `VitalsPreferencesImpl` precedent), `AppLanguage` + `AppLocaleController` (the one plan-level design decision: per-app locale override via UserDefaults `"AppleLanguages"` + bundle swizzle-on-launch, ruling 6), and `MeasurementInput` ported into `SalusCommon` (50–250 cm / 20–400 kg, comma-tolerant parse — the M2 `toValueOrNull` precedent). Premium-dependent rows land as stand-ins (`FreeOnlyPremiumStatus`-style narrow protocol, divergence-(d) pattern): More shows the Premium/Doctor-report/Trends rows but the gates test only the free branches; entitlement branches land with M9. Onboarding: `FeatureOnboarding` is an overlay the shell draws above everything (not a nav destination — the back stack and pending deep links survive the gates, Android's comment verbatim), `includeNotificationStep` is always true on iOS (the permission concept exists), the notification permission request runs in the Route. Lock: `AppLockManager` sits in `App/Lock/` (twin of Android's `app/lock/` — it is app-shell code, not a feature), observes `preferences.userSettings.appLockEnabled` + scenePhase; `LAContext.evaluatePolicy(.deviceOwnerAuthentication)` is the BIOMETRIC_WEAK-or-DEVICE_CREDENTIAL twin (system renders the credential UI, failure/cancel = no-op, the Unlock button is the retry). Strings: settings catalog +74→87, onboarding catalog 54 (new package), app catalog +3; `AppStrings` + the two `more_cycle*` keys are deleted along with `PlaceholderScreen` (the M6 ruling-1 promise). A11y: the VoiceOver + Dynamic Type pass is a task of its own (T14) — every label, hint, trait and Dynamic-Type-safe layout this milestone's screens need, plus a sweep of the existing screens against the same bar.

**Tech Stack:** Swift 6 / SwiftUI, GRDB (existing), `LocalAuthentication` (system — the allowlist stays at three), `swift-testing`.

**Spec:** `salus-android/docs/ios-v1-plan.md` — §4 (shell = five tabs, gates as overlays), §6.2 (secure screen: always-on blur + masking toggle, wording "hide content in screenshots", never an absolute promise), §6.4 (TR default + fallback), §7 (banned claims), §8 (`MoreScreen`, `ProfileScreen`, `AboutScreen`, `OnboardingScreen`, app lock), the iOS-M8 entry ("String Catalogs for all 511 keys, VoiceOver pass, Dynamic Type pass at the largest sizes with Turkish strings"); `salus-android/docs/parity-ledger.md` row "Settings / More / onboarding / app lock / a11y | iOS-M8", S-2 (implementation lands here), S-23 (sex filters content, never the tab set — the cycle row gate). **Do not modify Android code** — the only Android-repo write is the parity-ledger docs commit in Task 16.

## Global Constraints

- **Rulings (coordinator, 2026-08-30 — planned against `main` at `aa696e5`, M7 fully merged with its final review wave; **confirmed by the user, 2026-08-30 — all ten as written**):**
  1. **App lock timing = scenePhase gate + 30 s background-duration grace.** `AppLockManager` records `backgroundedAtMs` on `.background`, re-evaluates on `.active`: `backgroundedAt == nil || now − backgroundedAt > 30_000` → re-lock. Cold start locked; disabling the setting unlocks instantly (derived `enabled && !unlocked`). The timeout constant `lockTimeoutMs: Int64 = 30_000` is injectable in tests only — fixed by product decision, no UI option (Android companion comment verbatim).
  2. **Secure screen = the §6.2 shape, not FLAG_SECURE.** Always-on app-switcher blur (a `PrivacyOverlay` view the shell draws on `.inactive`/`.background`) + `secure_screen_enabled` adds screenshot masking via the secure-text-field layer + `UIScreen.isCaptured` hides mirroring. Toggle wording uses the existing `settings_secure_screen` / `settings_secure_screen_desc` keys (Android-verbatim copy already says "hides screenshots and the recents preview" — "hide content in screenshots", never "blocks/prevents", satisfying §6.2's wording rule without a key change).
  3. **Onboarding gate order = Android's: onboarding overlay outermost, lock beneath.** "A first launch has nothing to lock." Both are overlays over `RootView`, never destinations. Onboarding state is `onboardingCompleted: Bool?` held `nil` until `userSettings` answers — the twin of the splash-hold: `RootView` draws nothing but the launch colour while nil (iOS has no `installSplashScreen`; `UILaunchScreen` in Info.plist already holds the screen, `RootView` just keeps drawing a blank until the first emission).
  4. **Enabling app lock re-authenticates first** (`LAContext`, title `settings_app_lock_confirm_title`), disabling does not; the prompt lives in the Route (Android's Route/VM split verbatim — the ViewModel stays testable). `appLockAvailable = LAContext().canEvaluatePolicy(.deviceOwnerAuthentication, error: nil)`; toggle disabled + subtitle swaps to `settings_app_lock_unavailable` when false.
  5. **Premium-gated rows are stand-ins until M9** (divergence-(d) pattern): `MorePremiumStatus { var status: AsyncStream<MorePremiumStatusValue> }` with `enum MorePremiumStatusValue { free, entitled }` (grace counts as entitled, Android semantics); `FreeOnlyMorePremiumStatus` emits `.free` once, never finishes. Free branches (paywall request, blocked persistence) tested now; the `OpenUrl`/`OpenDoctorReport` entitlement branches + `PaywallController` land with M9 — the effects exist, the tests for them are deferred with a recorded note. `PLAY_SUBSCRIPTIONS_URL` → `https://apps.apple.com/account/subscriptions` (platform-mapped; final value re-confirmed at M9).
  6. **Language switch = per-app override via `UserDefaults "AppleLanguages"`.** `AppLocaleController.current()` reads the stored override (absent → `.system`); `apply(language:)` writes `["tr"]`/`["en"]`/removes the key, and the change takes effect on the **next launch** (a sheet in-app alert is Android's `AppCompatDelegate` behaviour, which is also apply-on-recreate; a relaunch note in the dialog is the honest iOS twin — recorded divergence). `AppLanguage: String, CaseIterable { system = "SYSTEM", turkish = "TURKISH", english = "ENGLISH" }` — raw values Android-verbatim (persisted shape parity).
  7. **Onboarding weight → vitals history, profile write first, flag last** (Android comments verbatim): `finish()` saves the profile (existing row copied — `id`/`isDefault` survive), then `vitalsQuickEntry.recordWeight(kilograms:epochMs:timeZoneId:)` (the composition root already exposes it "for onboarding's current weight step (M6)"), then `preferences.setOnboardingCompleted(true)`. Process-death midway replays the flow.
  8. **Onboarding back is in-flow only** (`canGoBack: stepIndex > 0`); the flow can be stepped through, never escaped — no system-back escape, `BackHandler`'s twin is a `.interactiveDismissDisabled`-free overlay that ignores the edge swipe (the gate owns the screen). Skip **clears** the step's answer; Sex is the one hard gate (`isSkippable == false`, `canContinue` requires a pick).
  9. **`AppStrings` + `PlaceholderScreen` are deleted** with the two `more_cycle*` keys moving into `FeatureSettings`'s catalog (the M6 ruling-1 promise); the app catalog keeps only the three `app_lock_*` keys. `SalusUITests.AppStringCatalogTests` is rewritten to pin the 3-key set.
  10. **About's paddings use SalusSpacing tokens** (Android's hardcoded 16/12/8 dp are a fidelity note, not a rule to copy — recorded divergence), but the layout (app name headlineMedium primary, description bodyMedium, one privacy Card) is verbatim. No version on About (single home = the More footer, `CFBundleShortVersionString` read in the Route).
- **Recorded iOS divergences (write into the execution record, not silently):** (a) language apply takes effect on next launch (ruling 6); (b) premium stand-in is two-state not three (ruling 5 — grace folded into entitled; the full `PremiumStatus` enum lands with M9); (c) About uses spacing tokens (ruling 10); (d) `settings_back`/`profile_back` TopAppBar contentDescriptions are dropped (the shell draws the back button — the `reminder_health_back` M4/M6 precedent); (e) notification-permission request uses `UNUserNotificationCenter.requestAuthorization` in the Route, grant **or** denial always → `NextClicked` ("Denial is not a dead end"); (f) the onboarding gate's splash-hold is a blank `RootView` frame, not Android's `installSplashScreen`; (g) `HomeStringsTests`-style catalog pins grow (15→87 settings, 54 onboarding, 3 app); (h) `MeasurementInput` lands in `SalusCommon` with comma→dot normalization (the M2 `replacingOccurrences(",", ".")` precedent, Kotlin's `toDoubleOrNull` accepts no comma — recorded, the Turkish keyboard types one).
- **Never** reword `settings_app_lock_desc` ("30 sn arka planda kaldıktan sonra...") or any banned-stem copy; the S-8 scanner (`BannedHealthClaims`) runs repo-wide. Say "hide", never "block/prevent", in any new secure-screen copy (ruling 2, §6.2).
- Strings: settings catalog grows 15 → **87 keys** (74 owed, all TR+EN from the XML tables in the settings inventory §6; `%1$s`→`%1$@` in `about_version`); onboarding catalog **54 keys** (inventory applock §6; `%1$d/%2$d`→`%1$lld/%2$lld` in `onboarding_progress`, `onboarding_step_counter`); app catalog **3 keys** (`app_lock_*`). Every key set is pinned by a literal key-set test (`StringCatalogParity`, tr source, both locales).
- `Calendar` rule: onboarding/profile birth date stays `epochDay`/`LocalDate` end to end; `SalusDateField` (already ported, M2) is the only date UI. No new `Calendar` anywhere (the `no_calendar_outside_clock` rule is mechanical since M7 T1).
- Colors: More rows/icons use `theme.extendedColors` accents (`.cycle` on the cycle row icon tint, the Android accentTint twin); `SalusIconBadge` (exists) for the lock screen; theme dialogs list plain options. No new tokens. `Text(verbatim:)` for every resolved `Strings` accessor value passed to `Text` (the M7 `c726e22` finding — `Text(_:)` reads a `LocalizedStringKey` against the main bundle).
- Every task: `scripts/test-packages.sh <touched packages>` + `scripts/build-app.sh` green before commit; SwiftFormat/SwiftLint clean (file 500, type 300, function 60, params 6); `scripts/clean.sh` after adding a file to a path dependency; `project.yml` + regenerated `pbxproj` in the same commit; `NSFaceIDUsageDescription` lands in `App/Info.plist` (via `project.yml`'s `info:` block) with the T9 commit. Ported test files = Kotlin file name + `Tests.swift`; case names = Kotlin backtick names in camelCase. **No simulator or device work is ever an executor step** (user ruling, 2026-08-30): anything visual or interactive is a numbered row in `scripts/m8-manual-qa.md`, written by the task's executor, executed only by the user.
- Executors report: test names verified against the Kotlin files, every divergence from the Kotlin twin listed, nothing "fixed while passing" outside the task's files. Parallel tasks run in their own worktrees on `m8-t<N>` branches and are rebased onto `m8-settings-onboarding` before review.

**Dependency graph:** T0 ∥ T1 ∥ T2 (independent, parallel) → T3 (needs T1's accessor signatures compile-ready; T0 independent of it) ; T4 (needs T3) ∥ T5 (needs T0 + T1) → T6 (needs T4 + T5 + T3) ; T7 (needs T2 + T0) → T8 (needs T7 + T5's SalusOptionRow/SalusPillTextField) ; T9 (independent of T3–T8; needs nothing new) ∥ T10 (needs nothing new) → T11 (needs T6 + T8 + T9 + T10) → T12 (needs T11) → T13 (needs T12) → T14 (needs T13) → T15 (needs T14) → T16 (needs T15). Critical path: T1/T2 → T3 → T4 → T6 → T11 → T12–T16.

**M7 hand-offs this plan inherits (from the M7 execution record, `aa696e5`):**
- **Simulator and device QA are the user's job** (user decision, 2026-08-30, recorded in the M7 record and the ledger; **re-confirmed for M8: the executor runs zero simulator work**). Agents run tests, lint and the build, and write `scripts/m8-manual-qa.md` — nothing else. Every visual or interaction check this plan's tasks mention exists as a numbered `m8-manual-qa.md` § that the task's executor **writes** and never runs: no preview-render inspection, no scripted simulator interaction, no screenshot capture. An executor step is `scripts/test-packages.sh <touched packages>` + `scripts/build-app.sh` + lint, full stop.
- **`FreeOnlyPremiumStatus`'s exact shape is the M7-ratified pattern** (`D-M7-d`): emits its value **once and never finishes**. `FreeOnlyMorePremiumStatus` copies it verbatim (ruling 5).
- **A pushed screen hides the tab bar; a gate overlay must not fight it** (`D-M7-ab`'s note): `RootView`'s `observeNavigationCommands` memoizes the cycle-calendar push on stack **depth**. T11's onboarding/lock overlays sit **above the `TabView`, outside every `NavigationStack`** — they neither push nor clear the memo, but T11's QA rows must confirm a cycle reminder tapped from behind the lock (if one ever fires) still lands on exactly one calendar.
- **`vitalsQuickEntry`'s doc now says "(M8)"** (`66682ed`) — T7's onboarding `finish()` is the caller that doc names; cite it.
- **Feature-local premium protocols are the house shape** (`D-M7-t`): Home's `HomeAiSummaryAvailability`/`HomePremiumStatus` are the precedent More's `MorePremiumStatus`/`PaywallRequester` follow (ruling 5).
- **The plain-`TextField` editors are a known debt** (`D-M7-l`/`D-M7-y`): the three vitals editors share `VitalsEditorField` (caption + field + error stroke + suffix) — the shape `SalusPillTextField` (T5) and the onboarding/profile fields should copy, not the bare `TextField` the older editors grew from. The `SalusPillTextField` migration sweep of the vitals/medications/appointments editors stays out of scope (polish, not parity) but T5's component doc cites `VitalsEditorField` as its model.
- **String citations drift** (`c726e22`): every Kotlin line citation an M8 task writes is re-derived with `grep -n` at execution time, not copied from this plan or the inventories.
- **`Text(verbatim:)` for resolved strings** (`c726e22`): `Text(_:)` reads a `LocalizedStringKey` against the main bundle — every M8 screen rendering a resolved `Strings` accessor value goes through `Text(verbatim:)`.

---

### Task 0: Branch + `SalusCommon` — `MeasurementInput`

**Files:** Create `Packages/SalusCommon/Sources/SalusCommon/MeasurementInput.swift`, `Packages/SalusCommon/Tests/SalusCommonTests/MeasurementInputTests.swift`.

**Android reference:** `core/common/src/main/kotlin/com/alicansekban/salus/core/common/MeasurementInput.kt` — `object MeasurementInput` with `MIN_HEIGHT_CM = 50.0`, `MAX_HEIGHT_CM = 250.0`, `MIN_WEIGHT_KG = 20.0`, `MAX_WEIGHT_KG = 400.0`, `parseHeightCm(text)` / `parseWeightKg(text)` over a private `parse(text, min, max)`: `text.trim().toDoubleOrNull()` in range → value, else null. Divergence (h): the iOS `parse` first does `replacingOccurrences(of: ",", with: ".")` (the Turkish decimal comma, the M2 `toValueOrNull` precedent).

**Produces:** `public enum MeasurementInput { public static let minHeightCm = 50.0, maxHeightCm = 250.0, minWeightKg = 20.0, maxWeightKg = 400.0; static func parseHeightCm(_ text: String) -> Double?; static func parseWeightKg(_ text: String) -> Double? }` (enum-as-namespace, the `GlucoseConversion` shape).

- [ ] `git checkout -b m8-settings-onboarding` from `main` at `aa696e5` (M7 fully merged: ff-merge + the final review fix wave — `VitalsEditorField`, the token editor backgrounds, the cycle-memo seeding, the citation sweep — all in). Commit this plan first: `docs(plan): iOS-M8 settings hub, onboarding, app lock plan`.
- [ ] Tests first, ported by behaviour (Android has no test file for it — the constants and bounds are pinned by the *onboarding/profile* tests instead; iOS writes its own table): blank → nil; `"170"` → 170; `"170.5"` → 170.5; `"49"`/`"251"` → nil; `"300"` → nil; comma `"72,4"` → 72.4 (divergence (h)); weight `"20"`/`"400"` inclusive bounds pass, `"19.9"`/`"400.1"` nil; `"abc"`/`"  "` → nil.
- [ ] `scripts/test-packages.sh SalusCommon` green. Commit `feat(common): MeasurementInput — height and weight parse with the Turkish comma`.

### Task 1: `FeatureSettings` strings — the 87-key catalog

**Files:** Modify `Packages/Features/FeatureSettings/Sources/FeatureSettings/Resources/Localizable.xcstrings` (+74), `Sources/FeatureSettings/SettingsStrings.swift` (+74 accessors), `Tests/FeatureSettingsTests/SettingsStringsTests.swift` (pin 87).

**Android reference:** the settings inventory §6 — the three tables (More+dialogs 44, About 5, Profile 22, shared 3) are the complete key list with TR+EN values. The 15 reminder-health keys stay.

**Produces:** `SettingsStrings` accessors for every new key (grouped `enum More`, `enum About`, `enum Profile` namespaces inside, or flat — match the existing file's shape); formatted accessors `aboutVersion(_ version: String)`, and the dialog option accessors `theme(_ mode: ThemeMode)`, `colorTheme(_ theme: PremiumTheme)`, `language(_ language: AppLanguage)` (they read `theme_system`/`theme_light`/`theme_dark`, `color_theme_*`, `language_*` per case — Task 3 defines the enums; the accessor signatures land here so Task 4 compiles against them).

- [ ] Copy every TR/EN value from the inventory tables (the inventory was written from the XML — the executor re-verifies each against `salus-android/feature/settings/src/main/res/values{,-en}/strings.xml` and reports any mismatch as a finding, not a silent fix). `%1$s`→`%1$@` in `about_version`. The two `more_cycle*` keys arrive here from `AppStrings` (ruling 9).
- [ ] `SettingsStringsTests`: rewrite the key-set pin to the literal 87-key list; `assertSourceLanguage("tr")`, `assertEveryKeyIsLocalized`, TR+EN value tables for the new keys; `BannedHealthClaims` repo-wide stays green. `scripts/test-packages.sh FeatureSettings` green. Commit `feat(settings): the hub's 74 string keys — More, Profile, About (catalog 87)`.

### Task 2: `FeatureOnboarding` package + strings + `OnboardingUiState`

**Files:** Delete `Packages/Features/FeatureOnboarding/Sources/FeatureOnboarding/FeatureOnboarding.swift` + its placeholder test; create `Sources/FeatureOnboarding/Resources/Localizable.xcstrings` (54 keys), `Sources/FeatureOnboarding/OnboardingStrings.swift`, `ui/OnboardingUiState.swift`; tests `Tests/FeatureOnboardingTests/{OnboardingStringsTests,OnboardingUiStateTests}.swift`; modify `Package.swift` (`defaultLocalization: "tr"`, resources) — deps: SalusModel, SalusCommon, SalusUI, SalusDesignSystem, SalusNavigation, SalusProfile, SalusSettings (the manifest's existing list already resolves these transitively; the executor edits only what the imports need).

**Android reference:** applock inventory §5 (steps/sections/UiState/events verbatim) + §6 (the 54-key table). `enum OnboardingStep { welcome, name, sex, birthDate, height, weight, healthNotes, notifications }`, `enum OnboardingSection { personalDetails, healthNotes, privacy }`, section mapping (welcome → nil), `steps: [OnboardingStep]` (default `[.welcome]`), `stepIndex`, `name`, `sex: Sex?`, `birthDateEpochDay: Int?`, `heightText`, `weightText`, `healthNotes`, `isSaving`; derived `step`, `isLastStep`, `section`, `stepCount` (excl. welcome), `stepNumber` (1-based, 0 on welcome), `progress` (stepNumber/stepCount), `canGoBack`, `isSkippable` (welcome & sex excluded), `showInvalidHeight/Weight` (via `MeasurementInput`, T0), `canContinue`. Events: `nextClicked, backClicked, skipClicked, nameChanged(String), sexSelected(Sex), birthDateSelected(Int), heightChanged(String), weightChanged(String), healthNotesChanged(String)`.

- [ ] `OnboardingStringsTests`: `assertSourceLanguage("tr")`, the literal 54-key pin, both locales, TR+EN value tables; `%1$d`→`%1$lld`, `%2$d`→`%2$lld` in the two formatted keys. Port `OnboardingUiStateTest` (6 cases by name: welcome has no section; every step maps to its section; welcome is outside the counter; the counter runs one to seven over the collecting steps; progress never goes backwards across the flow; a shortened step list still counts to its own end — the 3-step `[.welcome, .name, .sex]` at index 2 → stepCount 2, stepNumber 2, progress 1).
- [ ] `scripts/test-packages.sh FeatureOnboarding` + `scripts/build-app.sh` green. Commits: `feat(onboarding): package, 54-key string catalog, UiState with the step machine`.

### Task 3: `FeatureSettings` domain — `SettingsPreferences`, `AppLanguage`, `AppLocaleController`, premium stand-in

**Files:** Create `Sources/FeatureSettings/domain/{SettingsPreferences,AppLocaleController}.swift`, `data/{SettingsPreferencesImpl,UserDefaultsAppLocaleController,FreeOnlyMorePremiumStatus}.swift`; tests `Tests/FeatureSettingsTests/{SettingsPreferencesImplTests,UserDefaultsAppLocaleControllerTests,MorePremiumStandInTests,FakeSettingsPreferences,FakeAppLocaleController,FakeMorePremiumStatus}.swift`.

**Android reference:** settings inventory §5. `public protocol SettingsPreferences: Sendable { var themeMode: AsyncStream<ThemeMode> { get }; var appLockEnabled: AsyncStream<Bool> { get }; var secureScreenEnabled: AsyncStream<Bool> { get }; var premiumTheme: AsyncStream<PremiumTheme> { get }; func setThemeMode(_ mode: ThemeMode) async; func setAppLockEnabled(_ enabled: Bool) async; func setSecureScreenEnabled(_ enabled: Bool) async; func setPremiumTheme(_ theme: PremiumTheme) async }` — `SettingsPreferencesImpl(dataSource: SalusPreferencesDataSource)` maps each stream off `dataSource.userSettings` (distinct-until-changed guard, the M7 `VitalsPreferencesImpl` shape) and delegates each setter 1:1. `public enum AppLanguage: String, CaseIterable { system = "SYSTEM", turkish = "TURKISH", english = "ENGLISH" }`; `public protocol AppLocaleController: Sendable { func current() -> AppLanguage; func apply(_ language: AppLanguage) }`; `UserDefaultsAppLocaleController(defaults:)` reads/writes `UserDefaults` key `"AppleLanguages"` (ruling 6: `["tr"]`/`["en"]`/remove; absent → `.system`; **takes effect next launch** — the doc comment says so). `public enum MorePremiumStatusValue: Equatable, Sendable { free, entitled }`; `public protocol MorePremiumStatus: Sendable { var status: AsyncStream<MorePremiumStatusValue> { get } }`; `FreeOnlyMorePremiumStatus` emits `.free` once, never finishes (the `FreeOnlyPremiumStatus` M7 shape, ruling 5).

- [ ] Impl tests over `InMemoryAppLockFlagStore` + a scratch `UserDefaults` (`UserDefaults(suiteName:)`): each stream carries the stored value and updates on the setter; equal consecutive writes are dropped (distinct guard); app-lock writes go through the flag store, never the defaults (the `appLockFlagBypassesUserDefaults` shape). Locale-controller tests: default `.system`; apply `.turkish` → `["tr"]` stored + `current() == .turkish`; `.system` removes the key; `.english` → `["en"]`. Stand-in test: first emission `.free`, stream never finishes.
- [ ] `scripts/test-packages.sh FeatureSettings` green. Commit `feat(settings): SettingsPreferences, AppLanguage and the locale controller; premium stand-in`.

### Task 4: `MoreViewModel` + state

**Files:** Create `Sources/FeatureSettings/ui/more/{MoreUiState,MoreViewModel}.swift`; tests `Tests/FeatureSettingsTests/{MoreViewModelTests,FakeProfileRepository(extend the ReminderHealth one if it exists there — otherwise create),FakePaywallRequester}.swift` (or single `MoreFakes.swift`).

**Android reference:** settings inventory §1. State fields verbatim (§1 table): `isLoading=true, profileName="", showCycle=false, themeMode=.system, premiumTheme=.classic, language=.system, premiumStatus=.free (MorePremiumStatusValue), appLockEnabled=false, secureScreenEnabled=false, activeDialog: MoreDialog?` where `enum MoreDialog { theme, colorTheme, language }`. Events: `dialogRequested(MoreDialog), dialogDismissed, selectTheme(ThemeMode), colorThemeSelected(PremiumTheme), selectLanguage(AppLanguage), setAppLock(Bool), setSecureScreen(Bool), premiumClicked, doctorReportClicked, trendsClicked`. Effects: `openUrl(String), openDoctorReport, openTrends` — buffered (a `pendingEffects: [MoreEffect]` array + `consumeEffects()`, the `ReminderHealthViewModel` pendingEffect shape generalized; Android's `Channel.BUFFERED` = nothing dropped, the array twin). `@MainActor @Observable MoreViewModel(profileRepository:premiumStatus:preferences:localeController:paywallRequester:)` where `protocol PaywallRequester: Sendable { func show(_ source: PaywallSource) }` and `enum PaywallSource { themes, settings, doctorReport }` (feature-local stand-in types — M9 replaces with the real `PaywallController`; the gate logic reads `premiumStatus.status` first value, not state). `showCycle = profile != nil && profile.sex != .male` (nil keeps the row — S-23). `stateIn(5_000)` twin = the M7 ruling-3 re-subscribe-on-appearance precedent: observation starts in `init` (a `latestOf` fold over profile + the four preference streams + a language/locale holder, the `SecondaryState` bundling pattern from the Kotlin), `restartObservation()` re-runs it; `MoreRoute.task` calls it on every appearance. `constant appStoreSubscriptionsUrl = "https://apps.apple.com/account/subscriptions"` (ruling 5).
  - Event gates: `colorThemeSelected` entitled → persist + close; free → close + `paywallRequester.show(.themes)`. `premiumClicked` entitled → `openUrl(appStoreSubscriptionsUrl)`; free → `show(.settings)`. `doctorReportClicked` entitled → `openDoctorReport`; free → `show(.doctorReport)`. `trendsClicked` never gated → `openTrends`. `selectLanguage` → `localeController.apply` + close. `selectTheme` → persist + close. `setAppLock/setSecureScreen` → persist.

**Interfaces:**
- Consumes: `SettingsPreferences` (T3), `AppLocaleController` (T3), `MorePremiumStatus`/`MorePremiumStatusValue` (T3), `ProfileRepository` (SalusProfile), `MeasurementInput` (T0 — via state? No: only Profile uses it; More never parses).
- Produces: `MoreUiState`, `MoreDialog`, `MoreEvent`, `MoreEffect`, `MoreViewModel`, `PaywallRequester`, `PaywallSource` (feature-internal except `MoreViewModel`).

- [ ] Port the 20 `MoreViewModelTest` cases by name (inventory §7): cycle visibility 4 (initial isLoading+hidden; female/other/null shown; male hidden; sex change re-emits without recreating), settings 5 (state carries stored preferences; theme select persists+closes; language applies+closes — `apply` called once; dismiss leaves untouched; security toggles persist), premium 4 (state follows entitlement — the fake flips `.free`→`.entitled`; free tap → paywall `.settings`, no effects; entitled tap → `openUrl`, no paywall — **testable now via the fake**, only the real-controller wiring is M9), doctor report 3 (free → paywall `.doctorReport` never the screen; entitled → `openDoctorReport`; entitled again for grace-folded — use the fake's `.entitled`), colour themes 4 (stored carried; entitled persists+closes; entitled(grace) persists; free pick → paywall `.themes`, stored stays `.classic`, dialog closes).
- [ ] `scripts/test-packages.sh FeatureSettings` green. Commit `feat(settings): MoreViewModel — the hub state, gates and buffered effects`.

### Task 5: Profile — `ProfileUiState` + `ProfileViewModel` + screen + key

**Files:** Create `Sources/FeatureSettings/ui/profile/{ProfileUiState,ProfileViewModel,ProfileScreen}.swift`; modify `navigation/SettingsNavigation.swift` (`ProfileKey: Hashable, Sendable` + destination); test `Tests/FeatureSettingsTests/ProfileViewModelTests.swift` (8).

**Android reference:** settings inventory §2. State verbatim: `isLoading=true, name="", sex=nil, birthDateEpochDay=nil, heightText="", healthNotes="", storedSex=nil, isSaving=false, showSexChangeConfirm=false`; computed `showInvalidHeight` (blank ok, `MeasurementInput.parseHeightCm` nil → invalid), `cycleVisibilityChange: CycleVisibilityChange?` (`enum { appears, disappears }`; compares `showsCycle()` stored vs pending where `showsCycle() = sex != .male` — null counts as showing). Events: `nameChanged, sexSelected(Sex), birthDateSelected(Int), heightChanged, healthNotesChanged, saveClicked, sexChangeConfirmed, sexChangeDismissed`. `ProfileViewModel(profileRepository:navigator:)`: loads once in `init` via `getProfile()`; `formatHeight` prints `"165"` not `"165.0"`; `saveClicked` guards invalid-height/isSaving; `disappears` → confirm dialog (no write); else `save()`; `sexChangeConfirmed` → clear + save; `sexChangeDismissed` → clear + **restore `sex = storedSex`**; `save()` copies the existing row (`id`, `isDefault` survive; `emptyProfile()` guard with `SalusDatabase.defaultProfileId` reached via `SalusProfile`), trims name, blank optional → nil, then `navigator.pop()`. Screen: form in the Android field order (name → sex `SalusOptionRow` ×3 with the Female/Male/Transgender icons + accents (FEMALE → `.cycle`, MALE → `.vitals`, OTHER → default) + the inline `profile_sex_cycle_appears/disappears` warning when `cycleVisibilityChange != nil` → birth date `SalusDateField` → height (suffix "cm", error text) → health notes (multi-line)), TopBar save disabled while `isLoading || isSaving || showInvalidHeight`, `SalusConfirmDialog` for the sex change (4 keys).
  - `SalusOptionRow` and `SalusPillTextField` do not exist — create both in `SalusUI` (`component/SalusOptionRow.swift`, `component/SalusPillTextField.swift`) in this task with their own `SalusUITests` (API tests — init arguments, selected-state round-trip, error-state flag; any visual check is the user's QA). `SalusPillTextField`'s doc and shape cite `VitalsEditorField` (M7's `D-M7-y`) as the model — caption + field + error stroke + suffix — rather than a bare `TextField`; onboarding T8 reuses both. The `SalusPillTextField` migration of the older vitals/medications/appointments editors stays out of scope (polish, not parity).

**Interfaces:**
- Consumes: `MeasurementInput` (T0), `ProfileRepository`, `Navigator` (SalusNavigation), `SalusOptionRow`/`SalusPillTextField` (created here in SalusUI).
- Produces: `ProfileKey`, `ProfileRoute(entryId-less)`, `ProfileViewModel`, `ProfileUiState`, `CycleVisibilityChange`, `SalusUI.SalusOptionRow`, `SalusUI.SalusPillTextField`.

- [ ] Port the 8 `ProfileViewModelTest` cases by name (inventory §7): loads stored profile (height "165"); blank optionals save as null + id kept; out-of-range height blocks; female→male asks confirmation; null→male asks too; female→other no dialog; male→female no dialog; cancel restores storedSex + no write. Fake: `FakeProfileRepository` (saved list) + `FakeNavigator` (commandLog — the M7 `FeatureHomeTests` copy precedent).
- [ ] `scripts/test-packages.sh FeatureSettings SalusUI` + build green. Commits: `feat(ui): SalusOptionRow and SalusPillTextField`, `feat(settings): profile editor — state, view model, screen, key`.

### Task 6: More screen + About + settings navigation completion

**Files:** Create `Sources/FeatureSettings/ui/more/MoreScreen.swift`, `ui/about/AboutScreen.swift`; modify `navigation/SettingsNavigation.swift` (`AboutKey` + `settingsDestinations(onOpenCycle:onOpenDoctorReport:onOpenTrends:)` — the three shell callbacks, Android's `settingsEntries` signature twin), `SettingsModule.swift` (grow: `makeMoreViewModel`, `makeProfileViewModel`, `preferences`, `localeController` built from inputs), `App/AppCompositionRoot+Modules.swift` (`makeSettingsModule` grows its inputs — `premiumStatus: FreeOnlyMorePremiumStatus()`, `localeController: UserDefaultsAppLocaleController(defaults: .standard)`, `preferencesDataSource`, `profileRepository` — the M7 split file is where feature graphs are built; the parameter list grows past 6 → `swiftlint:disable function_parameter_count`, the `VitalsModule` precedent), `App/AppCompositionRoot.swift` (only the call site's arguments + any new `let`s).

**Android reference:** settings inventory §1 (rows table) + §3. `MoreRoute(onOpenCycle:onOpenDoctorReport:onOpenTrends:appLockPrompt:)` — Route owns: the LAContext availability check (`appLockAvailable`), the enable-re-auth interception (ruling 4: `setAppLock(true)` routes through `LAContext.evaluatePolicy(.deviceOwnerAuthentication)` with title `settings_app_lock_confirm_title` — a `prompt(_ title: String) async -> Bool` closure injected from the shell so the Route itself stays LAContext-free and previewable), `openSettingsURL` for the notification row (`UIApplication.openSettingsURL` — the `ACTION_APP_NOTIFICATION_SETTINGS` twin), `CFBundleShortVersionString` for the footer, effect consumption (`openUrl` → `UIApplication.shared.open`, runCatching-twin `try?`; `openDoctorReport`/`openTrends` → the shell callbacks). `MoreScreen(state:versionName:appLockAvailable:onEvent:callbacks)` — rows in the §1 draw order (13 rows + 4 section labels + footer), private `MoreCard` (icon + title + subtitle + `SalusListItemChevron` — create it in SalusUI here too, the `SalusEmptyState`-component precedent), `MoreToggleCard` (a `Toggle` row), `SelectionDialog` (a radio-list confirmationDialog/alert with the shared `settings_cancel`). Colour-theme subtitle = the **effective** theme (lapsed → classic) — `SalusDesignSystem`'s resolved value, the inventory §8 note. About per ruling 10 (tokens, no version, back via the shell).
  - Cross-feature rows at M8 time (inventory §8): Premium row + Doctor report row + Trends row render; their entitlement branches fire effects the shell maps to callbacks that **no-op with a TODO(M9/M10/M11) comment** (the placeholder precedent); free branches open the paywall requester — the paywall itself is M9, so `PaywallRequester.show` is a recorded no-op log until then (ruling 5's deferred half).

**Interfaces:**
- Consumes: T4 (`MoreViewModel` + effects), T5 (`ProfileKey`), T1 strings, T3 (`AppLanguage`).
- Produces: `MoreRoute`, `MoreScreen`, `AboutKey`, `AboutRoute`, `settingsDestinations(onOpenCycle:onOpenDoctorReport:onOpenTrends:)`, grown `SettingsModule` + `makeSettingsModule`, `SalusUI.SalusListItemChevron`.

- [ ] Write `scripts/m8-manual-qa.md` §4 rows (13 rows render, Profile push + save, About push, theme/color/language dialogs apply, app-lock toggle prompts Face ID with enrolled biometrics, notification row opens system settings) — written, never run. `#Preview` code ships in the screens (for the user's later inspection) but the executor does not render-check it. `scripts/test-packages.sh FeatureSettings SalusUI` + build green. Commits: `feat(settings): the More hub screen, rows and selection dialogs`, `feat(settings): About screen`, `refactor(settings): settingsDestinations with the three shell callbacks; module factories grown`.

### Task 7: `FeatureOnboarding` domain — preferences + ViewModel

**Files:** Create `Sources/FeatureOnboarding/domain/OnboardingPreferences.swift` (protocol + impl in one file or `data/OnboardingPreferencesImpl.swift` — match the feature template's `domain`/`data` split), `ui/OnboardingViewModel.swift`; tests `Tests/FeatureOnboardingTests/{OnboardingViewModelTests,FakeOnboardingPreferences,FakeVitalsQuickEntry}.swift` (FakeProfileRepository copied, the template-sanctioned copy precedent).

**Android reference:** applock inventory §5. `public protocol OnboardingPreferences: Sendable { func setCompleted() async }`; `OnboardingPreferencesImpl(dataSource: SalusPreferencesDataSource)` → `dataSource.setOnboardingCompleted(true)`. `@MainActor @Observable OnboardingViewModel(profileRepository:vitalsQuickEntry:preferences:clock:includeNotificationStep: Bool = true)`: `state: OnboardingUiState` with `steps = OnboardingStep.allCases.filter { $0 != .notifications || includeNotificationStep }`; events per T2; `advance()` blocked by `!canContinue`; last step → `finish()`; `skipClicked` → `clearCurrentStep()` (clears name/birthDate/heightText/weightText/healthNotes — welcome/sex/notifications untouched) + advance; `finish()` (ruling 7): guard isSaving, set it, then in a Task: profile write first (`getProfile() ?? emptyProfile()` copied with `displayName = name.trim()`, sex, `birthDate = LocalDate(epochDay:)`, `heightCm = MeasurementInput.parseHeightCm(heightText)`, `healthNotes = trimmed.takeIf { !isEmpty }`), then `vitalsQuickEntry.recordWeight(kilograms:epochMs: clock.now().epochMs, timeZoneId: clock.timeZone().id)` when weight parses, then `preferences.setCompleted()`; `emptyProfile()` = `Profile(id: SalusDatabase.defaultProfileId-via-SalusProfile, …, isDefault: true)`.

**Interfaces:**
- Consumes: `OnboardingUiState` (T2), `MeasurementInput` (T0), `SalusModel.VitalsQuickEntry`, `SalusProfile.ProfileRepository`, `SalusSettings.SalusPreferencesDataSource`, `SalusClock` (SalusCommon).
- Produces: `OnboardingViewModel`, `OnboardingPreferences`, `OnboardingPreferencesImpl`, `OnboardingModule` (see T8 — built here? No: T8 builds the module; this task produces the VM + preferences only).

- [ ] Port the 7 `OnboardingViewModelTest` cases by name (inventory §8): notification step dropped when includeNotificationStep=false (iOS passes true in prod — the case still ports against the false flag); sex is the one hard gate; back on the first step is a no-op; an unusable measurement blocks the step but a blank one does not ("7" invalid, "" continue); skipping clears what the step collected; finishing writes the profile, the first weight and the completion flag (name "  Ada  " trimmed, FEMALE, 1990-06-15, height 170, weight "72,4" → `(72.4, nowMs, "Europe/Istanbul")` — `FixedSalusClock(now: 1_750_000_000_000)`); a skipped weight writes no measurement and blank notes stay null.
- [ ] `scripts/test-packages.sh FeatureOnboarding` green. Commit `feat(onboarding): OnboardingViewModel and preferences — profile first, weight, flag last`.

### Task 8: Onboarding screens — Header, Hero, StepContent, Screen + module

**Files:** Create `Sources/FeatureOnboarding/ui/{OnboardingScreen,OnboardingHeader,OnboardingHero,OnboardingStepContent}.swift`, `OnboardingModule.swift` (+ `@Entry var onboardingModule`); modify `Package.swift` only if an import needs it.

**Android reference:** applock inventory §5 (UI structure). `OnboardingRoute` = template Route (module from environment, VM in `@State`); full-screen gate: applies its own insets (safeArea + ime) — "the app's only other inset owner"; back = in-flow only (ruling 8: no escape — the overlay ignores the edge swipe; a `. gesture` is unnecessary because an overlay full-screen cover has no nav container to swipe). Notification permission: `.task` on the notifications step asks `UNUserNotificationCenter.requestAuthorization([.alert, .sound, .badge])` — grant **or** denial → `nextClicked` (divergence (e)); the Allow button fires the request, the Later skip button (`onboarding_notifications_later`) advances without asking. `OnboardingHeader` (all but welcome): back button (in-flow), centred section title over a 128×4 `ProgressView(.linear)` (progress a11y label `onboarding_progress`), circular counter badge (32, `primaryContainer`/`onPrimaryContainer`, `onboarding_step_counter`, `.accessibilityHidden(true)` — "the bar next to it already announces the position", the M7 sparkline-ruling-7 precedent). Footer: full-width `SalusPillButton` (welcome → `onboarding_start`, notifications → `onboarding_allow_notifications`, last → `onboarding_finish`, else `onboarding_next`; enabled `canContinue`; notifications → CheckCircle icon else arrow — SF Symbol twin). Skip `TextButton`-twin (`onboarding_skip` / later) when `isSkippable`, disabled while saving. Step bodies: welcome = hero + title/body; name = `SalusPillTextField` (placeholder, person-name autocapitalization, submit); sex = `SalusOptionRow` ×3 (T5's component — the accents/icons identical to Profile); birthDate = `SalusDateField`; height/weight = decimal fields with suffix "cm"/"kg" + invalid text; healthNotes = 240-tall editor + `SalusStatusChip(onboarding_notes_private, success, lock)` + the Shield privacy card; notifications = hero + benefit card (`SalusListItem`-twin → a `SalusCard` row — `SalusListItem` does not exist; build the row inline, the Android `SalusListItem` is app-local to that screen). `OnboardingHero` = decorative shapes (shield cluster / bell+heart badge), `.accessibilityHidden(true)`. `makeOnboardingModule(profileRepository:vitalsQuickEntry:preferencesDataSource:clock:)` + `OnboardingModule { makeOnboardingViewModel }`.

- [ ] Write `scripts/m8-manual-qa.md` §1 rows (the full walk: skip-paths, sex gate blocking Next, back mid-flow with first-step no-op, comma weight "72,4", finish writing profile + weight + flag — check via More → Profile shows the name; Vitals weight chart has one entry) — written, never run. The 7 step `#Preview`s ship in the code for the user's later inspection. `scripts/test-packages.sh FeatureOnboarding` + build green. Commit `feat(onboarding): the eight-step flow — header, hero, step content, screen, module`.

### Task 9: App lock — `AppLockManager` + `AppLockScreen` + strings + Info.plist

**Files:** Create `App/Lock/{AppLockScreen,LockPrompting}.swift` (they import SwiftUI/`LocalAuthentication` and draw); **place `AppLockManager` in a testable spot:** it has no UIKit dependency — put it in `Packages/SalusCommon/Sources/SalusCommon/AppLockManager.swift` with its tests in `SalusCommonTests` (the `PendingDeleteController` precedent — shell-logic-in-common with the shell injecting it). Modify `App/Localizable.xcstrings` (+3 `app_lock_*` keys) + `App/AppStrings.swift` (+3 accessors), `project.yml` (`info: properties: NSFaceIDUsageDescription` — the TR base, same as `NSAlarmKitUsageDescription` today) + `App/tr.lproj/InfoPlist.strings` + `App/en.lproj/InfoPlist.strings` (the TR/EN peers — **all three together**, the existing files' own "Edit the three together" rule) + regenerate pbxproj.

**Android reference:** applock inventory §1–§2, §7. `@MainActor @Observable AppLockManager(appLockEnabled: AsyncStream<Bool>, clock: any SalusClock)`: `private var unlockedThisSession = false`, `private var backgroundedAtMs: Int64?`, `public private(set) var isLocked = true` (derived on each change: `enabled && !unlocked`), `public static let lockTimeoutMs: Int64 = 30_000` (ruling 1); `func sceneDidBecomeActive(nowMs: Int64?)` → re-evaluate: `backgroundedAtMs == nil || nowMs! − backgroundedAtMs! > lockTimeoutMs` → `unlockedThisSession = false`; `func sceneDidEnterBackground(nowMs: Int64)` → record; `func unlock()` → `unlockedThisSession = true`. The shell (`SalusApp`) owns the wiring: observes `preferences.userSettings.appLockEnabled` (distinct) into the manager, feeds scenePhase timestamps from `clock.now().epochMs`. `AppLockScreen(onUnlockRequest:)`: full-screen background, centred `SalusIconBadge(lock, large)`, title `app_lock_locked_title`, `SalusPillButton(app_lock_unlock)`; auto-prompt on entry (`.task`), the button is the retry; no back handling (it's an overlay above the nav root). Prompt: `LAContext().evaluatePolicy(.deviceOwnerAuthentication, localizedReason: app_lock_prompt_title)` — success → closure; failure/cancel → no-op (the gate stays, Android verbatim).

**Interfaces:**
- Consumes: `SalusClock` (SalusCommon), `SalusPreferencesDataSource` (wiring), `SalusUI` components.
- Produces: `SalusCommon.AppLockManager`, `App.AppLockScreen`, `App.LockPrompting` (`makeLockPrompt() -> @MainActor (String) async -> Bool`).

- [ ] Port the 6 `AppLockManagerTest` cases by name (inventory §8): cold start is locked when the setting is on; never locks while the setting is off; unlock clears the gate; short background stay keeps the session unlocked (timeout − 1 s); exceeding the timeout in the background re-locks (timeout + 1 s); disabling the setting while locked unlocks immediately. Use `FixedSalusClock`/advanceable fake (the M7 `HomeViewModelTests` clock precedent). App-catalog pin test: rewrite `AppStringCatalogTests` to the 3-key set (ruling 9 — this is where AppStrings' two `more_cycle*` accessors die; the M6 promise closes). Write the `scripts/m8-manual-qa.md` §3 rows (enable via re-auth, 30 s grace both sides of the boundary, disable, no-biometrics subtitle) — written, never run.
- [ ] `scripts/test-packages.sh SalusCommon` + `scripts/build-app.sh` + lint green. Commits: `feat(lock): AppLockManager — the 30 s background grace`, `feat(lock): AppLockScreen + LocalAuthentication prompt; Face ID usage description`.

### Task 10: Secure screen — `PrivacyOverlay` + masking (S-2)

**Files:** Create `App/PrivacyOverlay.swift`; modify `App/RootView.swift` (apply the overlay + `UIScreen.isCaptured` observation), `App/SalusApp.swift` (nothing — the overlay reads the same `userSettings` stream the theme reader already observes; keep the single subscription site).

**Android reference:** none verbatim — this is the iOS §6.2 shape (ruling 2): (a) the app-switcher blur is **always on**: a `PrivacyOverlay` (the app icon/name on `Material`-twin blur) draws over `RootView` whenever `scenePhase != .active`; (b) `secure_screen_enabled` adds screenshot masking via the secure-text-field layer (a zero-size `UITextField` with `isSecureTextEntry = true` planted in the window — the documented iOS technique; wrap in `#if !targetEnvironment(simulator)` if the simulator artefacts demand it, and say so); (c) `UIScreen.isCaptured` (observed via `NotificationCenter` / CADisplayLink-lite polling on the capture change) hides content while mirroring. Wording: the toggle copy is the existing `settings_secure_screen_desc` ("hides screenshots and the recents preview") — "hide", never "block" (§6.2's absolute-promise rule).

- [ ] No Kotlin test twin and no app test target exists (user decision: leave it that way — the shell logic stays covered by review + manual QA, not a new bundle). The overlay's visibility logic is still a pure function — `PrivacyOverlay.State.resolve(scenePhase:isCaptured:maskingEnabled:)` in the file — so the rule is stated in code and compile-checked, but its table verification is the user's: `scripts/m8-manual-qa.md` §2 rows (app switcher shows the blur; toggle on → screenshot captures black; AirPlay-mirror → content hidden), simulator **and** device. Commit `feat(app): the §6.2 secure screen — always-on switcher blur, masking toggle, capture hiding`.
- [ ] Build + lint green. Commit `feat(app): the §6.2 secure screen — always-on switcher blur, masking toggle, capture hiding`.

### Task 11: Shell wiring — More tab, gates, `AppStrings` deletion

**Files:** Modify `App/RootView.swift` (the More tab root: `MoreRoute(...)` with the three callbacks — `onOpenCycle: { root.navigator.navigate(CycleKey()) }` (the existing pattern), `onOpenDoctorReport`/`onOpenTrends` → no-op TODO(M10/M11); `.settingsDestinations(...)` on the More stack; the onboarding + lock overlays **above the `TabView` and outside every `NavigationStack`** — `if root.appLockManager.isLocked { AppLockScreen(...) }` then `if onboardingCompleted == false { OnboardingRoute().environment(\.onboardingModule, …) }`, onboarding **outermost** in z-order, ruling 3; the overlays neither push nor clear the cycle-calendar depth memo (`D-M7-ab`) — T11's QA rows confirm it; delete `PlaceholderScreen.swift` + its usage), `App/AppCompositionRoot.swift` (+`let appLockManager: AppLockManager` built over `infrastructure.preferences.userSettings` (distinct) + `clock` — the Koin `appModule` twin; +`let onboardingModule`), `App/AppCompositionRoot+Modules.swift` (the grown `makeSettingsModule` inputs land here, T6; +`makeOnboardingModule` wiring if it exceeds the root's line budget), `App/AppStrings.swift` (delete the two `more_cycle*` accessors — ruling 9; the enum keeps the 3 lock keys), `App/SalusApp.swift` (feed the manager from the existing `onChange(of: scenePhase)` switch — the same `.active`/`.background` arms that drive `reminderDidBecomeActive()`/`commitPendingDeletes()` gain the manager calls, keeping the single scenePhase subscription site; **the splash-hold**: a `@State onboardingCompleted: Bool?` on `RootView` fed by the first `userSettings` emission; while nil, `RootView` draws a plain `Color` frame). Modify `project.yml` only if files/targets changed structure.

- [ ] Build + full `scripts/test-packages.sh`. Write the `scripts/m8-manual-qa.md` rows the wiring owns (fresh install → onboarding full walk → lands on Home; kill + relaunch → no onboarding; More tab: 13 rows, cycle row present for FEMALE profile, absent for MALE; enable app lock + Face ID → background 31 s → foreground → lock screen → unlock; More → cycle push still memo-safe behind the overlays) — written, never run. Commit `feat(app): mount the More hub; the onboarding and lock gates; delete the placeholder`.

### Task 12: Language wiring + cross-check

**Files:** Modify `App/SalusApp.swift` (nothing extra — the locale override is launch-time `UserDefaults`, no runtime wiring), `Sources/FeatureSettings/ui/more/MoreScreen.swift` (the language dialog's relaunch note: a footnote `Text` under the options — the `language_*` keys stay Android-verbatim; the note itself is an iOS-only key `language_relaunch_note` TR "Değişiklik, uygulamayı yeniden açtığınızda uygulanır." / EN "The change applies the next time you open the app." — **an iOS-only string addition, recorded divergence (a)**; pin it in the catalog test).

- [ ] `scripts/test-packages.sh FeatureSettings` + build green (catalog parity + `BannedHealthClaims` included). Write the `scripts/m8-manual-qa.md` §5 rows (dialog → Türkçe → relaunch → TR; → English → relaunch → EN; → Sistem dili → device language) — written, never run. Commit `feat(settings): the language switch applies on next launch — relaunch note`.

### Task 13: Acceptance sweep + execution record

**Files:** Modify this plan (execution record: commits per task, review rounds, divergences (a)–(h) + any found, rulings 1–10 confirmed by the user 2026-08-30, deferred findings, Android follow-ups); **consolidate `scripts/m8-manual-qa.md`** — the §'s were written by their tasks along the way (T8 §1, T10 §2, T9/T11 §3, T6 §4, T12 §5, T14 §6, T11 §7): T13 verifies each task's rows are present, renumbers if needed, and adds the §0 preamble (fresh-install setup: delete the app to reset onboarding; the Keychain note that a reinstall keeps `app_lock_enabled`).

- [ ] `scripts/ci.sh` end to end at the branch tip (5/5 green; paste the summary into the record). Whole-branch final review by the coordinator. Commit `docs(settings,onboarding,lock): M8 execution record and manual QA script`.

### Task 14: The VoiceOver + Dynamic Type pass

**Files:** Create `docs/a11y-audit-m8.md` (the audit worksheet — per-screen findings); modify the screens this milestone shipped + any existing-screen findings (each fix its own commit, or one sweep commit if small).

**Spec reference:** the iOS-M8 entry: "VoiceOver pass, Dynamic Type pass at the largest sizes with Turkish strings." Scope: every M8 screen (More, Profile, About, Onboarding ×8 steps, AppLock) + a sweep of the existing seven surfaces (Home, Vitals ×3 editors + list, Medications list/detail/editor ×N, Appointments list/detail/editor, Cycle calendar/log, ReminderHealth, dialogs/snackbars). Method: VoiceOver rotor walk (every control labelled — the typed `Strings` enums give real labels; decorative shapes hidden — the M7 sparkline precedent; the onboarding counter badge hidden), Dynamic Type at AX5 largest with TR strings (the longest TR value drives layout — e.g. `onboarding_notifications_body`, `about_privacy_body`; no fixed heights that clip; `minimumScaleFactor` only where Android wraps too), focus order follows the draw order, the lock screen and gates announce themselves.

- [ ] The executor's half is code only: label/trait/hiding declarations (every control labelled through the typed `Strings` enums, decoratives `.accessibilityHidden(true)`, `.lineLimit(nil)` where Android wraps — no fixed heights that clip), each verified by build + existing tests. The rotor walk, the focus-order check and the AX5-TR layout inspection are the user's — the executor **writes** `scripts/m8-manual-qa.md` §6 rows and never runs them. Every code-level finding is recorded in `docs/a11y-audit-m8.md` with what was fixed; easy fixes on existing screens land in M8 (user ruling), the rest are deferred rows. Commit `feat(a11y): the M8 VoiceOver and Dynamic Type declarations — labels, traits, hidden decoratives`.

### Task 15: Manual QA — handed to the user

- [ ] The executor's job ends at `scripts/m8-manual-qa.md` being complete, runnable and committed (T13 writes it; every task above added its §). **Executing it is the user's** (the M7 user decision, 2026-08-30: simulator and device QA are the user's job; agents run tests, lint and the build). The execution record carries a "still owed, by the user" section listing `m8-manual-qa.md` end to end — the simulator sections plus the device-only rows (§2 secure screen on device, §3 Face ID + Keychain, §7 the full device pass; the M5/M6/M7 device passes are still outstanding too, per the M7 record). Commit `docs(m8): manual QA script finalized for the user`.

### Task 16: Parity ledger + docs

**Files:** Android docs-only commit on `salus-android/docs/parity-ledger.md`: the Settings/More/onboarding/app-lock/a11y row → "iOS-M8 ✅ (cases: 20 More + 8 Profile + 6+7 onboarding + 6 lock + strings parity)"; close S-2 (implementation landed); proposed follow-ups unnumbered (`A?`): language apply-on-relaunch divergence (ruling 6), `about_privacy_body`'s Google Play/RevenueCat naming on iOS (App Store naming — copy decision recorded, kept verbatim this milestone per the parity rule; flag for a joint copy pass), the two-state premium stand-in → full `PremiumStatus` at M9 (ruling 5), `language_relaunch_note` iOS-only key, `SalusPillTextField` migration sweep for the older editors (T5 created it; the vitals/medications/appointments editors still use plain `TextField`s — a polish sweep, not parity). Modify `docs/ios-feature-template.md` if a rule changed (gates-as-overlays shape, the `AppLockManager`-in-`SalusCommon` precedent).

- [ ] The Android ledger commit lands **local-only, never pushed** (the M7 ruling-16 practice: a write outside this worktree is a stop-class side effect; the user owns the push), then the iOS final commit `docs(parity): iOS-M8 settings, onboarding, app lock — divergences and follow-ups` referencing it. **The `--ff-only` merge and the push are held for the user**, as in iOS-M3 through M7. Both repos' CI-equivalents green.

## Self-review notes (written at planning time)

- Spec coverage: More hub ✓ (T1, T3–T6), Profile ✓ (T5), About ✓ (T6), onboarding 8 steps + gates ✓ (T2, T7, T8, T11), app lock 30 s + biometric ✓ (T9, T11), S-2 secure screen ✓ (T10), 511-key localization closure ✓ (T1 settings 87, T2 onboarding 54, T9 app 3 — the last catalogs; the other 367 keys landed with their milestones), VoiceOver + Dynamic Type ✓ (T14), `NSFaceIDUsageDescription` ✓ (T9), key pins Android-verbatim ✓ (T1/T2/T9 pin tests), sex-gate row ✓ (T4 `showCycle`), `MeasurementInput` ✓ (T0).
- Type consistency: `AppLanguage` raw values (T3) = what `MoreUiState.language` (T4), the `SettingsStrings.language(_:)` accessor (T1) and the dialog (T6) use; `MorePremiumStatusValue` (T3) is what T4 gates and T6 renders; `AppLockManager` API (T9: `sceneDidBecomeActive(nowMs:)`/`sceneDidEnterBackground(nowMs:)`) is what `SalusApp` (T11) calls; `OnboardingUiState.steps` (T2) is what T7's VM builds and T8's header counts; `MeasurementInput.parseHeightCm` (T0) is what T5 (profile) and T7 (onboarding) parse with; `SalusOptionRow`/`SalusPillTextField` (T5, SalusUI) are what T6 (no — More doesn't use them; T8's sex/name steps do) use.
- Known tension, flagged: T4's `MoreViewModel` reads language from `localeController.current()` once (Android semantics) while the dialog's apply needs a relaunch anyway (ruling 6) — consistent, but the state's `language` field can go stale within a session if the override is edited directly in Settings.app; accepted (Android has the same class of staleness across process death). T10's `UIScreen.isCaptured` observation has no snapshot API — polling or the capture notification; the executor picks and records. T11's splash-hold: `userSettings` is an `AsyncStream` that emits promptly; if the Keychain read is slow, the blank frame is the honest twin of the splash (recorded divergence (f)). The cycle-calendar depth memo (`D-M7-ab`) is untouched by the overlays but T11 verifies the reminder-then-reminder ordering still memoizes.
- M7 deltas folded in: QA is the user's (executors run zero simulator work — every visual check is a written `m8-manual-qa.md` row), `FreeOnlyMorePremiumStatus` copies the exact M7 `FreeOnlyPremiumStatus` shape (`D-M7-d`), `AppCompositionRoot+Modules.swift` is the split the T6/T11 graph work edits, `NSFaceIDUsageDescription` edits all three files together (plist base + both `InfoPlist.strings`), Kotlin citations are re-derived with `grep -n` at execution time, `Text(verbatim:)` everywhere a resolved string reaches `Text`.
- All ten rulings confirmed by the user, 2026-08-30 (app lock timing, §6.2 secure screen, gate order + blank-frame splash-hold, re-auth-to-enable, two-state premium stand-in, language apply-on-relaunch, about copy verbatim + tokens, no app test target, a11y easy-fixes-in-M8, Face ID text, onboarding no-escape). Executors run zero simulator work — every visual check is a written `m8-manual-qa.md` row the user executes.
- Not in scope: the real `PaywallController`/`PremiumStatus` three-state + entitlement effects (M9), `AiSummaryKey` (M10), Trends destination (M11), backup (M12), `SalusListItem` as a shared SalusUI component beyond what these screens need inline, `SalusPillTextField` migration of the older editors (polish), an app-target test bundle (flagged).

---

# Execution record (iOS-M8)

Written by Task 13 on 2026-08-30 at branch `m8-settings-onboarding`, HEAD `76e14bf`, 34 commits
above `main` (`cdc33e1..76e14bf`). Every commit SHA below exists in the branch; every verdict,
ruling and deferred minor is carried from `.superpowers/sdd/2026-08-30-ios-m8-settings/progress.md`
and cross-checked against the task reports. **Correction note:** where this record disagrees with the
plan text above (the string counts in the header, Self-review and divergence (g)), this record is
right and the plan text is the stale planning-time estimate — the errata sub-section below is the
correction vehicle; the plan's Global Constraints text is deliberately left untouched so its history
stays.

**Status of the two later tasks at the time of writing — T14 (a11y pass) and T16 (parity ledger)
are PENDING.** They land after this record. Their subsections below are honest placeholders; the
coordinator appends their outcome (commit SHAs + verdicts) once their own commits land on this
branch.

## Commits per task

| Task | Commits (newest first within the range) | Shipped | Tests / gates at the time |
|------|------------------------------------------|---------|---------------------------|
| T0 Branch + `MeasurementInput` | `cdc33e1` (plan), `614ab3e`, `dea0d34` | `MeasurementInput` in `SalusCommon` | 15 new cases (9 height + 6 weight), SalusCommon 52→53 total |
| T1 | `7446fba` | settings catalog 87 keys, `SettingsStrings` accessors | 20 tests / 3 suites, 87-key pin |
| T2 | `fd400f3` | `FeatureOnboarding` package, 45-key catalog (P-4), `OnboardingUiState` | 11 tests / 2 suites (6 UiState + 5 strings) |
| T3 | `425944e` | `SettingsPreferences`, `AppLanguage`, `AppLocaleController`, premium stand-in | domain suites pass |
| T4 | `b1720e6` | `MoreViewModel` + state, buffered effects | 20 `MoreViewModel` cases; 56 tests / 7 suites |
| T7 | `ededde6`, `fbd0207` | `OnboardingViewModel`, `OnboardingPreferences` | 7 Kotlin cases + 1 iOS-only abort; 19 tests / 3 suites |
| T10 | `eaaf9fe` (= `bef1009` replayed), `a101b03`, `5693300` | §6.2 secure screen — `PrivacyOverlay` + masking | SalusTesting 30→32 tests / 5 suites |
| T9 | `3d0d696`, `ffdf33b`, `d61e872` | `AppLockManager`, `AppLockScreen`, Face ID description | 6 Kotlin + 2 iOS-only `AppLock` cases; SalusCommon 61 |
| T5 | `2644d4f`, `d8606fb`, `f0d59d6`, `8da55f2` | `SalusOptionRow`/`SalusPillTextField` (SalusUI), profile editor + key | 8 Kotlin + 10 SalusUI + 1 pin (nil-profile); FeatureSettings 65→66 |
| T7 H-6 | `916e6f1` | onboarding reaches the default profile id via `SalusProfile` | FeatureOnboarding 19, lint 0 |
| T6 | `fbfe32a`, `d8f591a`, `9675c46`, `de45c2d`, `6bb009d` | More hub + About + settings navigation completion | FeatureSettings 68 / 9, SalusUI 89 / 14 |
| T8 | `caaa9dc`, `3cd7230`, `28365bc` | the eight-step onboarding screens + module | FeatureOnboarding 19 / 3 |
| T11 | `965db8c`, `f30ef1c` | More tab mount, gates, `AppStrings` lock keys | Salus+Common 2/2, build OK |
| T12 | `5097e15`, `a032522`, `d8c7dc5`, `76e14bf` | `language_relaunch_note`, QA §5, H-10 tab-bar keys, notes | SalusTesting 32 / 5 |

Total: 34 commits, linear (`cdc33e1..76e14bf`), no merge commits. T13's own commits append below.

## Review rounds (per task)

| Task | Review verdict | Fix rounds | Re-review |
|------|----------------|-----------|-----------|
| T0  | Spec ❌ → C1 (whitespace), I1 (no newline test) | 1 | clean |
| T1  | Spec ✅, no findings | 0 | — |
| T2  | Spec ✅, minors only (M-1 commit message 54 vs 45; M-2 unused helper) | 0 | — |
| T3  | Spec ✅, M-3 (impl access `internal`) | 0 | — |
| T4  | Spec ✅, M-4/M-5 (stream duplication, value-equal writes) | 0 | — |
| T5  | Spec ✅, Quality Needs work — C1 (sex-change alert saved old sex), I1 (`ImeAction.Next` dropped) | 1 | r1 clean |
| T6  | Spec ⚠️ — C1 (effects stranded), I1–I3; H-7 recorded | 1 | r1 clean |
| T7  | Spec ✅, Quality Approved — I-1 (`finish()` silent catch, parked H-4) + H-6 (import swap) | 1 | clean |
| T8  | Spec ✅, Quality Approved — I1 (loading branch not opaque) | 1 | r1 clean |
| T9  | Spec ✅, Quality Approved — I1 (missing QA row), I2 (`hasReadSetting` public) | 1 | r1 clean |
| T10 | Spec ❌ / Quality Needs work — C1 + I1–I3; round 2 accessibility finding | 2 | r1 + r2 clean |
| T11 | Spec PASS, Quality Approved — I1 (dead `vitalsQuickEntry`) | 1 | r1 clean |
| T12 | Spec ✅, Quality Approved — I1 (stale `AppStrings` doc) | 1 | r1 clean (1 comment-only minor parked → T13) |

## Recorded divergences — the plan's (a)–(h) and how each resolved

- **(a) language apply-on-relaunch** — delivered (T3 `UserDefaultsAppLocaleController`, T6 dialog,
  T12 `language_relaunch_note`). The note is an iOS-only catalog key (settings catalog's 88th).
- **(b) two-state premium stand-in** (`free`/`entitled`, grace folded in) — delivered (T3), full
  `PremiumStatus` deferred to M9.
- **(c) About spacing tokens** — delivered (T6, ruling 10).
- **(d) shell-drawn back buttons drop `settings_back`/`profile_back`** — delivered; **H-8 carved out the
  onboarding back button**, restoring `onboarding_back` (catalog 46) because the onboarding gate draws
  its own back chevron and the shell precedent does not hold for an overlay gate.
- **(e) notification permission in the Route; denial → `NextClicked`** — delivered (T8).
- **(f) blank-frame splash-hold (no `installSplashScreen`)** — delivered (T11 `SplashHoldCover`).
- **(g) catalog-pin growth** — see the errata below. The plan text's "15→87 settings / 54 onboarding /
  3 app" is the stale estimate; the real triple is **88 / 46 / 8**.
- **(h) `MeasurementInput` comma normalization** — **RETRACTED by ruling P-1.** Kotlin
  `MeasurementInput.kt:26` already does `text.trim().replace(',', '.')` before `toDoubleOrNull()`,
  so the comma replace is a verbatim port, not an iOS-only addition. No divergence.

## Divergences found in execution (beyond the plan's list)

- **D (H-7)** — More callbacks live on `MoreRoute(…onOpenCycle:onOpenDoctorReport:onOpenTrends:)`, not
  on `settingsDestinations(onOpenCycle:…)` as the plan named them: the More tab root is a Route, the
  destinations are pushes, and the callbacks belong where the effects are consumed. Recorded in
  `SettingsNavigation.swift`/`MoreScreen.swift`.
- **D (H-8)** — `onboarding_back` restored against divergence (d): the overlay gate draws its own back
  button, so the key survives; onboarding catalog is **46**, pin updated, used as the button's a11y
  label (see (d)).
- **D (H-10)** — the five `nav_*` tab-bar keys ported Android-verbatim; app catalog 3 → 8, pin
  updated, `RootTab.label` resolves through `AppStrings`. Unlocalized tab bar was the most visible
  §6.4 violation (T12). `nav_cycle` is dead on Android and `app_name` = `CFBundleDisplayName`, both
  recorded.
- **D (H-4)** — `finish()`'s write failure is swallowed silently (no error UI), matching Kotlin
  parity; the step reopens and the write is retryable. QA §1.9 notes "no error UI by design".
- **D (P-4 → H-8, count)** — onboarding 45 keys at T2 (P-4: Android XML carries 46, not the plan's
  54; the inventory §6 table lists 46; its summary line "54" was an arithmetic error). H-8 restored
  `onboarding_back` → **46**.
- **D (T12 total)** — the repository total is **409 keys × 2 locales across ten catalogs** (T12
  verified on the compiled bundle with `plutil`, 409 in `tr` and 409 in `en`), not the plan's "511".
  511 was quoted from the Android spec counting the whole Android tree, never the iOS tree.
- **D (H-9)** — `appLockAvailable`/`versionName` filled in `.task` show a one-frame pop; accepted
  (`LAContext.canEvaluatePolicy` in `init`/body would re-run per `RootView` evaluation).
- **D (H-2/H-3)** — `.captured` hiding is gated on `secure_screen_enabled` (mirroring/recording stay
  usable when the toggle is off); no `#if !targetEnvironment(simulator)` on the mask is needed (QA
  §2.4 is device-only and names the `#if` as the fix if the simulator artefacts demand it).
- **D (H-6)** — onboarding reaches the default profile id through `SalusProfile.ProfileRepositoryDefaults`,
  not `SalusDatabase` (the leak rule).
- **D (T5, divergence 11)** — `ImeAction.Next` (advance-on-return-key) is not ported; Profile's notes
  field keeps the newline key. Recorded in `ProfileScreen.swift`'s Material→SwiftUI table.
- **D (T9, divergence 3)** — `AppLockManager.isLocked` starts `true` (Android starts `false`), so an
  unread setting never draws app contents; gated behind `hasReadSetting` + the splash-hold. QA
  §3.16/§3.17 confirm no flash.
- **D (T7, divergence 3)** — a failing onboarding write skips the completion flag and reopens the
  step (abort path); pinned by the 8th iOS-only test.
- **D (T6, divergence 7)** — the three More pickers are sheets that draw the stored selection, not
  Kotlin's `AlertDialog` radio list; a SwiftUI `alert` cannot hold selection state.
- **D (T6, divergence 2)** — the LAContext availability/enable-re-auth prompt is shell-injected via
  `MoreRoute`'s `appLockPrompt` closure; `openSettingsURLString` is iOS's only notification-Settings
  destination (divergence 3); the notification-row badge uses the `.vitals` accent stand-in
  (divergence 6). All recorded in the `MoreScreen.swift` header.
- **D (T10)** — masking field added to the **window**, not the host view; `remove()` and the `.active`
  re-assert survive the worst case. `PrivacyOverlay.State` name kept verbatim per the brief.

## Coordinator rulings H-1…H-10 and P-1…P-4

All made during execution (full text in the ledger; one line each here — the plan already carries
user-confirmed rulings 1–10, not re-duplicated):

- **P-1** — (h) comma normalization retracted as a divergence (Kotlin already does it); port verbatim.
- **P-2** — `SettingsStrings.language(_:)` deferred to T3 beside `AppLanguage` (T1 compiles alone).
- **P-3** — T9 rewrites the app-catalog pin to the 3-key set; catalog and Swift accessors are separate
  files. (Superseded by H-5/H-10.)
- **P-4** — onboarding catalog is 45 keys (Android XML carries 46, not 54; the plan's "54" is the error).
- **H-1** — T5 ∥ T7 ∥ T9 ∥ T10 run as parallel executors in worktrees, each rebased before review.
- **H-2** — `.captured` hiding gated on `secure_screen_enabled`.
- **H-3** — no `#if !targetEnvironment(simulator)` on the mask.
- **H-4** — T7's `finish()` silent catch accepted as Kotlin parity (recorded divergence).
- **H-5** — 5-key app-catalog pin at T9 (3 `app_lock_*` + 2 `more_cycle*`), trimmed to 3 by T11, then 8 by H-10.
- **H-6** — T7's `import SalusDatabase` swapped for `ProfileRepositoryDefaults.defaultProfileId`.
- **H-7** — More callbacks on `MoreRoute`, not on `settingsDestinations` args (recorded divergence).
- **H-8** — `onboarding_back` restored; onboarding catalog 46.
- **H-9** — `appLockAvailable`/`versionName` one-frame pop accepted.
- **H-10** — the five `nav_*` tab keys ported; app catalog 8 (supersedes the plan's 3).

## Errata — the plan's stale string counts (divergence (g))

The plan's Global Constraints and Self-review still say "15→87 settings, 54 onboarding, 3 app" and a
"511-key closure". The realized counts, verified against the tree (pin tests + the T12 `plutil`
bundle read), are:

| Catalog | Key count | Why it differs from the plan |
|---------|-----------|------------------------------|
| Settings | **88** | 87 + `language_relaunch_note` (T12, iOS-only, recorded divergence (a)). |
| Onboarding | **46** | Android XML carries 46, not 54 — the plan's inventory summary and §6 table disagreed; the table is right (P-4 → 45, H-8 → 46). |
| App | **8** | 3 `app_lock_*` + 5 `nav_*` (H-10, the unlocalized tab bar). |
| **Total** | **409 × 2 locales** | The plan's "511" counted the Android spec's whole tree, never the iOS tree; the ten iOS catalogs hold 409 keys in each of `tr` and `en` (T12, verified). |

The **pre-M8 baseline is 267 keys** (the M1–M7 catalogs). 267 + 88 + 46 + 8 = **409**. The parity
ledger row (T16) and `salus-android/docs/ios-v1-plan.md:177`'s "511" are reconciled by this errata;
the ledger is not edited here.

## Test-case counts vs Kotlin (the milestone's contract)

- **More (T4): 20 `MoreViewModelTest` cases** by name (cycle visibility 4, settings 5, premium 4,
  doctor report 3, colour themes 4) — all ported, verified against the inventory §7 table.
- **Profile (T5): 8 `ProfileViewModelTest` cases** + 1 iOS-only nil-profile case + 10 `SalusUI` API
  tests for the new components.
- **Onboarding UiState (T2): 6** cases; **ViewModel (T7): 7** Kotlin cases + 1 iOS-only abort path.
- **App lock (T9): 6 `AppLockManagerTest` cases** (all six port, 8 total with the 2 iOS-only ones).
- **Strings parity pins** per package (settings 88, onboarding 46, app 8) via `StringCatalogParity`;
  `BannedHealthClaims` runs repo-wide.

## Deferred findings (for the final whole-branch review)

Collected from each task's "Minor (deferred)" lines in the ledger. These are parked, not fixed —
triage at the branch's final review:

- **T0** — M1 `replacingOccurrences` pulls Foundation transitively into the leaf; M2 report said
  "15 tests" without noting +2 over the brief's 13.
- **T2** — M1 commit message says "54-key" but the catalog holds 45 (git log only); M2 unused
  single-arg `formatted(_:)` helper in `OnboardingStrings.swift:273` (private, SwiftLint-silent).
- **T3** — M3 `SettingsPreferencesImpl` + `FreeOnlyMorePremiumStatus` are `internal` (fine while the
  factory is in-package).
- **T4** — M4 `CurrentValueStream`/`FakeMorePremiumStatus` continuation bookkeeping duplication
  (collapse if a third copy appears); M5 `CurrentValueStream` pushes value-equal writes (no case
  depends on it).
- **T7** — M1 dead continuation registry in `FakeProfileRepository`; M2 tautological assertions (2);
  M3 `goTo` cascades where Kotlin `check` aborts; M4 profile-rebuild blind spot for a future
  defaulted field; M5 `waitUntil` yield-loop flake risk (inherited from T4).
- **T5** — weakened `single()` assertions (4 cases); autocorrect coupled to capitalization; 1970
  wheel seed; dropped `top(sm)`; the 7-param `makeSettingsModule` suppression shelf life (resolved by
  T6's factory restructure); whole-state replace in `form(from:)`; `person.2` + `3…8` visual
  judgements.
- **T9** — 2 stale Kotlin citations; untested `SalusIconBadge` knobs + the redundant
  `SalusEmptyState` private 72/32 copy; `SalusPillButton` rendering its label through `Text(_:)`
  (pre-existing M7 debt).
- **T10** — `PrivacyOverlay.State` name shadowing (kept verbatim per the brief); bounds-origin
  cancellation computed once; `remove()` early-return can strand the field if the root view is
  replaced; material opacity judgement (`.ultraThickMaterial` kept); badge accent `.vitals` stand-in
  (M-8); per-update mask allocation (mostly taken); z-order on restore (M-4).
- **T6** — 7 review minors (1, 3, 5, 6 taken in the fix) + `MoreEffectQueueTests` pin the queue not
  the collector; `SalusSectionHeaderDefaults` unpinned; `MoreScreen.swift` line count (491 then, now
  499); sheet content blanks during dismissal.
- **T8** — sex-row spacing `md` vs Kotlin `lg` (fixed in round 1, not recorded); notes placeholder
  offset (~8 pt); keyboard-bounce risk in the 240 pt editor (no QA row); back chevron 24 pt vs the
  24 dp box (QA 1.1); no test for `SalusPillButton.trailingSystemImage:` (M-5 acknowledged).
- **T11** — 500-line threshold fragility; `SplashHoldCover` theme `background` vs the launch-screen
  system background (one-frame grey step, QA-not-a-bug); unused `Equatable` on `RootGates`;
  view-with-logic file (`RootGates.swift`); no in-flight guard on the unlock prompt (port-faithful);
  redundant `@MainActor`; §7 vs §4 QA cross-references (kept deliberately non-duplicative).
- **T12** — `MoreScreen.swift` 499/500 and `RootView.swift` 497/500, both within three lines of the
  file-length gate; §5.6 (Deutsch → Turkish fallback) needs a real device config and has never run;
  `Text(_:)` with a resolved `String` rationale wording in the constraints doc (~90 pre-M8 sites
  untouched); `AppStrings.Key` has no mechanical catalog check (the app target cannot be imported by
  a package — kept in step by review alone).

## Stale-comment sweep (T13's own, closed here)

- `OnboardingModule.swift` doc — rewording to match the "composition root's graph builder passes
  it" reality (T11's flag), applied by T13.
- `MoreSelectionDialog.swift` `var footnote` doc — the justification sentence (the T12 re-review
  finding) corrected to "a `let` default is dropped from the memberwise init, not 'forced on call
  sites'", applied by T13.
- The false "one scenePhase subscription" comment in `SalusApp.swift` was **already fixed in
  `f30ef1c`** (now "The one scenePhase site that forwards to the graph"); verified — no residual.
- No other comment the reviews named remains open for T13.

## Still owed, by the user (manual QA)

`scripts/m8-manual-qa.md` is consolidated and committed by T13; **executing it is the user's job**.
Nothing has been run: **§1–§5 and §7 are NOT RUN (and §6, written by T14, is NOT RUN** — the a11y
rotor walk and AX5-TR layout inspection are the user's, never an agent's). The **device-only rows**
in particular are unexecuted: §2 (secure screen on
a device, incl. the screenshot mask and AirPlay capture hide), §3 (Face ID on a device + the Keychain
reinstall-survival check), §6.1.7 (VoiceOver over the lock gate and secure curtain) and §7's full
device pass. Per the M7 record, the **M5/M6/M7 device passes
are still outstanding too** — this milestone does not close them.

## Android follow-ups proposed (unnumbered `A?`, for T16 / the ledger)

- **Language apply-on-relaunch divergence** (ruling 6) — a relaunch note is the honest iOS twin of
  appcompat's apply-on-recreate; no Android write.
- **`about_privacy_body` Google Play / RevenueCat naming → App Store naming** — a joint copy pass is
  flagged; kept verbatim this milestone per the parity rule.
- **Two-state premium stand-in → full `PremiumStatus` at M9** (the real `PaywallController` and
  entitlement branches).
- **`language_relaunch_note` iOS-only key** — the settings catalog's 88th; no Android twin.
- **`SalusPillTextField` migration sweep** for the older vitals/medications/appointments editors
  (polish, not parity — T5 created the component).

## Task 14 / Task 16 — pending at the time of writing

- **T14 (VoiceOver + Dynamic Type): COMPLETE** — landed in three commits after T13 closed this record
  (see "T14 — the VoiceOver + Dynamic Type pass" below for commits and the verdict). Added
  `docs/a11y-audit-m8.md`, the label/trait/fix declarations, QA §6, and filled this subsection.
- **T16 (parity ledger, Android docs commit): PENDING.** `salus-android/docs/parity-ledger.md` row →
  "iOS-M8 ✅ (cases: 20 More + 8 Profile + 6+7 onboarding + 6 lock + strings parity ×2 locales)",
  S-2 closed; the commit lands **local-only, never pushed** (M7 rule). **State to be appended by the
  coordinator after T16 lands:** [T16 commit + push status].
- **T15 (manual QA)** is the user's; the record above's "Still owed" section is its checklist.

## T14 — the VoiceOver + Dynamic Type pass (what T14 fixed and deferred)

Written by T14 on `m8-settings-onboarding`, immediately after the CI summary below.

### What T14 committed

- **`feat(a11y): M8 VoiceOver and Dynamic Type declarations — labels, traits, hidden decoratives`**
  — the code half: six fixes on in-scope surfaces.
    - The shared components `SalusScreenHeader`, `SalusSectionHeader`, `SalusPillButton`,
      `SalusConfirmDialog` and `SalusSnackbarHost` pass their resolved `String` to `Text(_:)`,
      which reads it back as a `LocalizedStringKey` against the **main** bundle (the M7
      `c726e22` finding). Now `Text(verbatim:)`, a comment citing the finding on each. This is the
      one fix that touches every M8 screen at once (More, Profile, About, AppLock all render
      through these components), plus Reminder Health.
    - `MoreToggleCard`'s `Toggle` was announced as an unnamed "switch" (`Toggle("", …)`) — the
      app-lock and secure-screen toggles on the hub. Added `.accessibilityLabel(title)`, the row's
      own spoken text, so VoiceOver reads "Uygulama kilidi" / "Güvenli ekran".
    - `ReminderHealthScreen` passed five resolved strings through `Text(_:)` (verdict, honesty
      line, and the health-card title/description/fix button). All now `Text(verbatim:)`.
- **`docs(a11y): the M8 audit worksheet and QA §6`** — `docs/a11y-audit-m8.md` (the per-screen
  worksheet), `scripts/m8-manual-qa.md` §6 (§6.1 rotor walk + focus order, §6.2 AX5-TR layout;
  both written-and-NOT-RUN, with the §0 preamble note updated to say §6 has landed), and this
  subsection.

Verdict: **DONE**. `scripts/lint.sh` 0 violations, `scripts/test-packages.sh SalusUI
FeatureSettings` (2/2 passed; SalusUI 89/14, FeatureSettings 68/9), `scripts/build-app.sh` BUILD
SUCCEEDED. QA §6 is the user's and is **NOT RUN**.

### What T14 deferred (rows in `docs/a11y-audit-m8.md`)

**Deferred by design:**

- **M-2** — the app-lock disabled-switch explanatory copy (`MoreScreen.kt` shows the same disabled
  switch with no string; a new catalog key would be needed). Android ships none.

**Deferred in round 1, landed in Fix round 2.** Round 1 initially deferred five pre-existing
`Text(_:)`-on-resolved-string sites on the M2–M6 surfaces as a whole-branch sweep. The review
ruling — *"easy fixes on existing screens land in M8"* — reversed that: the full sweep now lands
here (`fix(a11y): land the five deferred Text(verbatim:) conversions`), across FeatureHome
(`HomeHeader`, `HomeCycleCard`), FeatureVitals (`VitalsScreen`, `VitalsListSections`, the three
editors, `VitalsEditorField`), FeatureMedications (detail, list `MedicationCard`, both editors,
`DoseTimesSection`), FeatureAppointments (detail, list, editor) and FeatureCycle (`CycleScreen`,
`CycleCalendarSections`, `CycleSummarySections`, `CycleReminderSections`, `CycleDayScreen`).

**M-2 is therefore the only row still deferred.**

### T14's audit result

The M7/M8 screens were already a11y-wired by their own tasks (T8's onboarding header/hero/counter,
the M7 sparkline precedent, shared component decoratives). T14's remaining code work was the six
fixes above plus the whole-branch verbatim sweep (all in Fix round 2); the rotor walk, focus-order
and AX5-TR layout checks are the user's, per QA §6.

## CI summary — `scripts/ci.sh` at `76e14bf`

Run by T13 as the acceptance sweep, end to end, at the branch tip:

```
############################################################
# 1/5  toolchain
############################################################
# 2/5  lint
############################################################
# 3/5  custom lint rules (planted fixtures)
############################################################
# 4/5  test (all packages)
############################################################
::group::[ 1/24] …        …   (all 24 packages: FeatureModel … FeatureHome … FeatureSettings … )
==> summary: 24/24 packages passed
############################################################
# 5/5  build (app scheme)
############################################################
** BUILD SUCCEEDED **
==> CI pipeline passed.
```

All five steps green: **toolchain 1/1, lint 0 violations, custom lint rules 1/1, test-packages
24/24, build-app BUILD SUCCEEDED**. Full log: `/var/folders/…T/opencode` copy at T13 write time;
verbatim tail (the last 40 lines) recorded in the T13 report.

<details>
<summary>Verbatim CI tail (the final lines of the run)</summary>

```
CreateUniversalBinary … Salus.app/Salus (from target 'Salus')
    lipo -create …/Objects-normal/arm64/Binary/Salus /…/Objects-normal/x86_64/Binary/Salus
CopySwiftLibs … (in target 'Salus')
ExtractAppIntentsMetadata (in target 'Salus' from project 'Salus')
2026-08-30 23:43:45.362 appintentsmetadataprocessor … Starting appintentsmetadataprocessor export
2026-08-30 23:43:45.373 appintentsmetadataprocessor … Writing Metadata.appintents
CodeSign … Salus.debug.dylib (in target 'Salus')
CodeSign … __preview.dylib (in target 'Salus')
CodeSign … Salus.app (in target 'Salus')
Validate … Salus.app (in target 'Salus')
** BUILD SUCCEEDED **
==> CI pipeline passed.
```

</details>