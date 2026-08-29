# Salus iOS — project rules

A 1:1 manual Swift port of `salus-android`. Every rule below names its **enforcement point**:
a lint rule, a test, or "review" (a human/agent check with nothing mechanical behind it yet).
A rule with no mechanism is still binding — it just costs more to break unnoticed.

Port contract (source of truth, versioned in the Android repo):
`salus-android/docs/ios-v1-plan.md` (§ references below) ·
`salus-android/docs/design/design-tokens.md` · `salus-android/docs/contracts/backup-format-v1.md`.
Milestone plans live in `docs/plans/`. Toolchain and CI usage: `README.md`.

## Settled decisions (do not relitigate)

- **The dependency allowlist is closed and is exactly three** (spec §3), each arriving with the
  milestone that needs it and never before: **GRDB** (iOS-M1/M2 persistence), **`purchases-ios`**
  (RevenueCat, premium), **`firebase-ios-sdk`** (FirebaseAI + FirebaseAppCheck, AI). Charts, PDF,
  crypto and biometrics come from the system. Nothing else is ever added, and the allowlist stays
  closed at three. The tree today has **exactly one** remote SPM dependency, arrived with iOS-M1:
  **GRDB.swift**, pinned `from: "7.11.1"`, declared in `Packages/SalusDatabase/Package.swift` and
  nowhere else. The other 23 manifests still declare `dependencies: []` or local
  `.package(path:)` entries only; the app reaches GRDB transitively, by linking `SalusDatabase`.
  A second `.package(url:)` line anywhere is a finding unless it is `purchases-ios` or
  `firebase-ios-sdk` arriving with its own milestone. — *enforcement: review of every
  `Package.swift` / `project.yml` diff.*
- Offline-first, local-only: no backend of ours, no analytics, no ad-hoc networking. The
  Android carve-outs (store billing, Firebase AI) arrive with their own milestones and
  nowhere else. — *review.*
- Deployment target **iOS 17**; bundle identifier **`com.alicansekban.salus`** (matches the
  Android `applicationId` — RevenueCat needs the two to be one project). The app ships from
  `Salus.xcodeproj`.
- **Swift 6 language mode everywhere, strict concurrency from day one**: `SWIFT_VERSION: "6.0"`
  in `project.yml` and `// swift-tools-version: 6.0` in all 24 manifests. Never downgrade a
  target to Swift 5 mode (`swiftLanguageMode(.v5)`) to silence a `Sendable` error — fix the
  model instead. — *enforcement: `project.yml` + the manifests; a downgrade is visible in the
  diff.*
- All project documentation, code comments and commit messages are **English**.
  Conversation with the user stays Turkish. — *review.*
- **UI framework:** SwiftUI. **Persistence:** GRDB (M2). **Charts:** Swift Charts, wrapped in
  `SalusUI` — features never import Charts directly (the twin of Android's Vico rule). The adapter
  shipped with iOS-M2: `ChartUiModel` + `SalusLineChart` in `Packages/SalusUI/Sources/SalusUI/chart/`.
  — *enforcement: `.swiftlint.yml` custom rule `no_charts_in_features` (severity: error), `included:`
  scoped to `Packages/Features/`, matching scoped and `@preconcurrency`-prefixed imports too; proven
  to actually fire by `scripts/lint-custom-rules.sh`, which plants a fixture inside the scope and an
  identical one outside it. Both run in `scripts/ci.sh`.*
- **The tab bar is the shell's, and it shows only on a tab's root**: `App/RootView.swift` applies
  `.toolbar(backStacks.isAtRoot(tab) ? .visible : .hidden, for: .tabBar)` to each tab's
  `NavigationStack`, so every pushed destination — detail, editor, Cycle, Reminder health, anything
  a future feature pushes — gets the full height, exactly as Android's `showBottomBar`
  (`SalusApp.kt:133-136`) does. A feature never writes `.toolbar(…, for: .tabBar)` itself.
  — *enforcement: `.swiftlint.yml` custom rule `no_tab_bar_toolbar_in_features` (severity: error),
  `included:` scoped to `Packages/Features/`, matching both the `.toolbar(_:for:)` and
  `.toolbarVisibility(_:for:)` spellings whose arguments name `for: .tabBar`; proven to actually
  fire by `scripts/lint-custom-rules.sh`, which plants a fixture inside the scope and an identical
  one outside it. Both run in `scripts/ci.sh`. The shell's own line is outside the scope, by design.*
- **`docs/ios-feature-template.md` is the reference for every new feature**, written from the
  shipped `FeatureVitals` and the section-for-section twin of
  `salus-android/docs/architecture/feature-template.md`. Copy its shape — package manifest,
  `domain`/`data`/`ui`/`navigation` layout, UDF state types, the shell/navigation-container rule,
  the Route/Screen split, `…Destinations()`, the module factory, the testing standard, Charts and
  Strings — rather than improvising a second one. The rules here bind; that file shows the shape
  they produce, so when the two disagree, this file wins and the template gets fixed. — *review.*

## Layer rules

- **No UI framework in the domain layer.** `Packages/SalusModel` and `Packages/SalusCommon` must
  never import SwiftUI, SwiftUICore, UIKit, UIKitCore, AppKit or WatchKit — including scoped
  imports (`import struct SwiftUI.Color`) and `@preconcurrency` forms. This is the iOS twin of
  Android's `salus.jvm.library` convention plugin.
  — *enforcement: `.swiftlint.yml` custom rule `no_ui_framework_in_domain` (severity: error),
  scoped by `included:` to those two packages.*
  - **Pitfall, do not step on it:** `swiftlint --path …` silently disables custom rules — it
    changes the path SwiftLint resolves per file, the `included:` regexes stop matching, and the
    guard reports 0 hits while the rest of the run looks healthy. Lint the **repo** (`swiftlint
    --strict` from the repo root, what `scripts/lint.sh` does), or pass files **positionally**.
    Never `--path`.
- **Records and DAOs live in `SalusDatabase`; mappers live with the domain type.** Every GRDB row
  type is a `…Record` under `Packages/SalusDatabase/Sources/SalusDatabase/Records/`, every DAO is a
  small struct beside them, and neither ever leaves the package: a repository maps the record to
  the `SalusModel` type before returning it (`SalusProfile/ProfileMappers.swift` is the shape).
  This is the iOS twin of Android's "Room entities never leak into feature domains; mappers are
  mandatory". — *enforcement: review; a leak is visible as `import SalusDatabase` in a package that
  is not a repository.*
- **`LocalDate` is `SalusModel`'s, and `epochDay` is the wire.** Days are stored and passed as
  `epochDay` (`Int`); the calendar type around them is `SalusModel.LocalDate`, hand-ported from
  `kotlinx.datetime.LocalDate` so both platforms do the same proleptic Gregorian arithmetic. Never
  use `Foundation.Date`, `Calendar` or `DateComponents` for a *day* — they carry a time zone and a
  user calendar, which is exactly the drift the port is avoiding. `Date` stays for absolute instants
  only (`epochMs + tz_id`).
  - **The carve-out is the instant↔day conversion itself**, which has no other correct form:
    turning a `Date` into the day it falls on in a zone needs a calendar. Both directions live in
    `SalusCommon/SalusClock.swift` — `today()`, `todayEpochDay()` and `minuteOfDayNow()` reading
    a fixed *Gregorian* `Calendar` in the clock's zone (never `Calendar.current`, which follows the
    device's region and would answer a different year for the same instant), and the same boundary
    read backwards in `instant(of:minuteOfDay:)` / `LocalDateTime.instant(in:)`, the twin of
    `LocalDateTime(date, time).toInstant(zone)` that composes an editor's saved timestamp
    (`EditorMeasuredAt.kt:37`). Everything downstream of that boundary is `LocalDate` / `epochDay`
    integer math.
  - **There is exactly one other sanctioned `Calendar` in the tree, and it is not in this file's
    gift**: `SalusReminder/platform/UserNotificationGateway.swift`'s `trigger(at:)`, which
    decomposes an occurrence instant into the wall-clock `DateComponents` that
    `UNCalendarNotificationTrigger` demands — the API takes components, not a `Date`, so there is
    no way to schedule without one. It is pre-existing (iOS-M3) and it reads the same fixed
    Gregorian calendar in the reminder's zone. **Two files, `SalusClock.swift` and
    `UserNotificationGateway.swift`, and no third**: a `Calendar` anywhere else in the tree is the
    finding this rule is for. Recorded here in iOS-M4 because both files used to call themselves
    the last one.
  — *enforcement:
  `Packages/SalusModel/Tests/SalusModelTests/LocalDateTests.swift` + review.*
- **The composition root owns the singletons; there is no container.** `App/AppCompositionRoot.swift`
  is the one place a real dependency is constructed — the twin of Koin's `salusModules`
  (`AppModules.kt`) — and it holds each as a `let`. No global, no `static let shared`, no service
  locator: `SalusApp` creates the instance and injects it with `.environment(_:)`, so a test builds
  its own graph. A type that needs a dependency takes it in `init`; it never reaches for one.
  - **There is exactly one sanctioned `static let shared`, and it is
    `App/Reminder/AlarmActionBridge.swift`** (iOS-M5). An `AppIntent` is instantiated by the
    *system*, through the `init()` the protocol requires, in a process iOS may have launched for no
    other reason than to run that one intent — there is no call site to inject the graph through, so
    the intent needs a rendezvous point it can reach by name. The bridge is that point and nothing
    else: `AppCompositionRoot` binds the `ReminderActionDispatcher` it built into it, and the bridge
    forwards to that one dispatcher. It is not a locator — nothing else is ever resolved from it,
    and the only names outside `App/Reminder/` are the composition root's single `bind` line and
    its comments. Any *other* `shared` is the finding this rule is for.
  — *enforcement: review of any `static` mutable state or new `shared` accessor.*
- **Features never depend on each other.** A `Packages/Features/Feature*/Package.swift` may
  depend on core packages only — never on another `Feature*`. Cross-feature navigation stays a
  shell callback (spec §4). — *enforcement: the manifests themselves (no Feature→Feature edge
  exists today) + review of every new/edited feature manifest.*
- **Packages mirror the Gradle modules 1:1** (spec §4): `SalusModel` ← `:core:model`,
  `SalusCommon` ← `:core:common`, `SalusDesignSystem` ← `:core:designsystem`, and so on for all
  24. A new module on either platform gets its twin on the other, with the same name shape. —
  *review; `scripts/test-packages.sh` discovers packages by manifest, so a new one is tested
  automatically.*
- **`.macOS(.v14)` in a manifest is a test-host concession, not a target.** `swift test` cannot
  run a bundle on an iOS simulator, so a package whose host build cannot succeed under
  `[.iOS(.v17)]` alone also declares `.macOS(.v14)`. **iOS 17 remains the ship target** and never
  ship-conditions on macOS. There are exactly three reasons a package qualifies, and 20 of the 24
  do:
  - **Reaches SwiftUI** — directly (`SalusDesignSystem`, and `SalusNavigation` since its
    `TabBackStacks` holds one `NavigationPath` per tab) or transitively (`SalusUI` and the ten
    feature packages). Thirteen packages.
  - **Reaches GRDB** — `SalusDatabase`, plus its dependents `SalusProfile`, `SalusAI`,
    `SalusReminder`. Four packages. GRDB's own manifest declares a macOS 10.15 floor; a manifest
    that names no macOS platform is read by SwiftPM as macOS 10.13, and the host build fails with
    *"the library 'SalusDatabase' requires macos 10.13, but depends on the product 'GRDB' which
    requires macos 10.15"*. The floor propagates, so every future package that links
    `SalusDatabase` inherits the concession — that is expected, not a smell.
  - **Reaches `Observation`** — `SalusCommon`, whose `PendingDeleteController` is `@Observable`
    (iOS 17 / macOS 14; the host build otherwise fails with *"'Observable()' is only available in
    macOS 14.0 or newer"*), plus its dependents `SalusSettings` and `SalusTesting`. Three
    packages, arrived with iOS-M1. `Observation` is not a UI framework, so the domain-layer rule
    below still holds — this is the same host-build mechanics as the two above, not an exception
    to it.

  The remaining four — `SalusModel`, `SalusBackup`, `SalusNotifications`,
  `SalusPremium` — stay `[.iOS(.v17)]`
  alone; do not add `.macOS` to a package that does not need it, and never add it to silence
  something other than these three. — *enforcement:
  `scripts/test-packages.sh` (host build) + `scripts/build-app.sh` (real iOS build).*

## Port fidelity rules

- **Domain logic is hand-ported 1:1 from Kotlin**, with the Android table-tests carried over as
  the drift detector. A ported type without its ported test table is an unfinished port. —
  *review.*
- **Behaviour differences only where spec §6 records a decision**: §6.1 the reminder window
  (7-day horizon capped at 60 of the 64 pending slots, constants injected so both platforms run
  the same tests) · §6.2 always-on app-switcher blur plus a *masking* toggle, never worded as an
  absolute screenshot block · §6.3 premium is per-platform, no entitlement state in backups ·
  §6.4 Turkish is the default **and the fallback** locale — a device set to neither TR nor EN
  gets Turkish, exactly as Android's `values/` default does. Anything else that differs is a bug,
  not a port decision. — *review against §6.*
  - The fallback is **set, not pending**: `project.yml` carries `options.developmentLanguage: tr`
    (which writes `developmentRegion = tr` into the generated project) *and*
    `settings.base.DEVELOPMENT_LANGUAGE: tr` (which `App/Info.plist` passes through to
    `CFBundleDevelopmentRegion`). Both lines are needed — the XcodeGen option does not feed the
    build setting, whose Xcode default is `en`. Changing the fallback to English would have to
    happen on both platforms together.
- **Every persisted key and value string is Android-verbatim** (spec §9): the 13 settings keys
  (`onboarding_completed`, `app_lock_enabled`, `secure_screen_enabled`, `theme_mode`,
  `premium_theme`, `glucose_unit`, `cycle_reminder_enabled`, `cycle_reminder_lead_days`,
  `cycle_reminder_minute_of_day`, `paywall_intro_shown`, `ai_free_summary_used`,
  `ai_calls_count`, `ai_calls_epoch_day`) and every enum raw value stored under them
  (`SYSTEM`/`LIGHT`/`DARK`, `CLASSIC`/`OCEAN`/`SUNSET`/`FOREST`). Never "improve" a key or a
  case spelling — the backup format's `settings` block and cross-platform support depend on them.
  — *enforcement: a pinning test per key, the pattern set by
  `Packages/SalusModel/Tests/SalusModelTests/ThemeSettingsTests.swift` against
  `ThemeMode.storageKey` / `PremiumTheme.storageKey` in `SalusModel/ThemeSettings.swift`.
  New key ⇒ new pinning test, same commit.*
- **The Keychain holds exactly one thing: `app_lock_enabled`.** Everything else lives in
  `UserDefaults`, so the two stores stay one decision rather than a habit. The lock flag is the
  exception because a flag that gates access to the app must not be clearable by deleting the app's
  defaults or by restoring a backup — hence `KeychainAppLockFlagStore` and
  `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`. Never move a second setting there, and never
  put health data there. — *enforcement:
  `SalusPreferencesDataSourceTests.appLockFlagBypassesUserDefaults` pins that the flag never lands
  in `UserDefaults`; the Keychain store itself is verified on device (it needs an entitlement
  `swift test` has no way to grant).*
- **The Room schema JSONs are copied, not authored, and re-synced on every schema bump.**
  `Packages/SalusDatabase/Tests/SalusDatabaseTests/Resources/RoomSchemas/*.json` are verbatim copies
  of `salus-android/app/schemas/…`, and `RoomSchemaParityTests` reads them to prove the GRDB
  migrations produce Android's tables, columns and indices. A schema change on either platform means
  re-copying the JSON for the new version **in the same commit** as the migration. — *enforcement:
  `RoomSchemaParityTests`, which fails the moment the two schemas diverge.*

## Design system rules

- **`salus-android/docs/design/design-tokens.md` is the only source of token values.** Never
  invent, round, or eyeball a color, spacing, radius, elevation or duration. If the doc lacks it,
  the doc gets updated on the Android side first.
  — *enforcement: `Packages/SalusDesignSystem/Tests/SalusDesignSystemTests/SalusDesignTokensTests.swift`
  pins **213 tokens** and **5 `FeatureAccent` sets** per theme, plus per-section tables against
  §1–§9 of the doc. Adding a token without the doc line fails the count.*
- **`SalusDesignSystem` is tokens only, no views** (mirrors Android's `:core:designsystem`).
  Shared views live in `SalusUI`. — *review.*
- **The resolved theme travels in the environment, never as a parameter.** A view reads
  `@Environment(\.salusTheme) private var theme` (`SalusThemeEnvironment.swift`); the shell resolves
  it once from the stored `theme_mode` plus the system appearance and applies `.salusTheme(_:)`.
  This is Compose's `MaterialTheme` CompositionLocal, and it is the reason no screen ever declares a
  `theme:` argument — threading one through four intermediate views is how a screen ends up drawing
  a stale palette. — *review; `SalusThemeEnvironmentTests` pins the default (light, classic) so a
  view rendered outside the shell still draws Salus tokens.*
- **Color literals live in `private enum` palettes**, one per theme/scheme
  (`LightPalette`, `DarkPalette`, `LightAccentPalette`, `ClassicLightValues`, …). Hoist
  many-argument literals out of the initializer call: nested `FeatureAccent(...)` /
  `Color(...)` expressions blow the Swift type-checker's expression budget and turn a build into
  a timeout. — *enforcement: the existing shape in
  `Packages/SalusDesignSystem/Sources/SalusDesignSystem/` + review; a regression shows up as a
  compile timeout in `scripts/test-packages.sh`.*

## Copy and localisation rules

- **Banned health-claims vocabulary applies to all user-facing copy** — and to the Swift sources
  and comments around it, as on Android. Banned stems, case-insensitive substrings: `uyum` ·
  `hedef aral` · `planlan` · `adher` · `complian` · `complie` · `comply` · `planned dos` ·
  `target range` (plus the dotted-İ foldings `compli̇an` / `compli̇e`). The correct phrase is
  **"kaydedilen doz" / "recorded doses"** — no `MISSED` dose row is ever written, so the ratio
  describes recorded doses only; calling it adherence turns a fact about records into a claim
  about someone's treatment (spec §7, §12). — *enforcement: `SalusTesting`'s `BannedHealthClaims`,
  the twin of Android's, run repo-wide from
  `Packages/SalusTesting/Tests/SalusTestingTests/BannedHealthClaimsTests.swift`: "no Swift source in
  the repository names anything banned" (`assertSourcesNameNothingBanned(roots:exemptFileName:)`)
  and "no string catalog in the repository names anything banned"
  (`assertCatalogsNameNothingBanned(paths:)`). Both fail loudly if the scan reaches zero files, so a
  broken path cannot pass as a clean tree. Both scans cover `Packages/` **and** `App/`: the catalog
  scan gained `App/` in iOS-M6, when the app target got a `Localizable.xcstrings` of its own.*
- **The AI/PDF disclaimer is verbatim and mandatory** on every AI output and every PDF page
  footer: TR *"Bu rapor bilgilendirme amaçlıdır, tıbbi tavsiye değildir."* /
  EN *"This report is for informational purposes only and is not medical advice."* — *review,
  then the same string test.*
- **TR + EN string parity.** TR is the default and the fallback (§6.4); EN is a full peer. Every
  key exists in both. Strings live in one `Localizable.xcstrings` per package under
  `Sources/<Package>/Resources/`, reached through a typed `enum` over `Bundle.module`
  (`VitalsStrings.swift`) — never a bare `String(localized:)` at a call site, which resolves against
  the *main* bundle and silently returns the key. — *enforcement: `SalusTesting`'s
  `StringCatalogParity` — `assertSourceLanguage` (tr), `assertKeys(of:are:)` against a literal key-set
  pin copied from the Android XML, and `assertEveryKeyIsLocalized` (both locales present and
  non-empty, no third locale). A new catalog gets its own test suite in the same commit; the shape is
  `Packages/Features/FeatureVitals/Tests/FeatureVitalsTests/VitalsStringsTests.swift`.*
  - **Placeholder mapping is the one place the port is not byte-for-byte**: Java's `%1$s` becomes
    `%1$@` (a Swift `String` under `%s` reads a C string pointer) and `%1$d` becomes `%1$lld`
    (Swift's `Int` is 64-bit). The sentence around the specifier never changes.
  - **A `.xcstrings` is compiled only by Xcode's build system.** `swift build` / `swift test` copies
    the catalog into the resource bundle verbatim, so a lookup under `swift test` finds no table and
    `String(localized:)` returns the key. String tests therefore assert against the **file**; the
    end-to-end check is `scripts/build-app.sh` plus a simulator run.

## Project file and build rules

- **`Salus.xcodeproj` is generated by XcodeGen from `project.yml` and committed.** Never
  hand-edit the `.pbxproj` or change settings in Xcode's inspector — edit `project.yml`, run
  `xcodegen generate`, commit both in the same commit. — *review of any diff that touches
  `Salus.xcodeproj/project.pbxproj` without `project.yml`.*
- **Local == CI.** `scripts/ci.sh` runs `check-toolchain.sh → lint.sh → lint-custom-rules.sh →
  test-packages.sh → build-app.sh`; `.github/workflows/ci.yml` calls the same five scripts and
  contains no command of its own. Run `scripts/ci.sh` before every integration — the twin of
  Android's `./gradlew build`. — *enforcement: the workflow.*
- **Lint gate:** `swiftformat --lint .` first, then `swiftlint --strict` (zero warnings), both
  repo-wide from the repo root. To format rather than check: `swiftformat . && swiftlint --fix`,
  in that order. — *enforcement: `scripts/lint.sh`.*
- **Custom-rule gate:** a SwiftLint custom rule is a regex plus an `included:` scope and **both
  halves fail silently** — a regex that matches nothing and a scope that matches no file look
  exactly like a clean tree. `scripts/lint-custom-rules.sh` plants, for each custom rule, a file
  that must trip it inside the scope and an identical file outside it, and fails unless the rule
  fired once inside and stayed quiet outside. Add a `check` block to that script in the same commit
  as a new custom rule. — *enforcement: `scripts/lint-custom-rules.sh`, step 3 of `scripts/ci.sh`.*
- **Test gate:** `swift test` for **all 24 packages** under `Packages/`; the script fails if any
  package fails, and fails loudly if it discovers zero packages. — *enforcement:
  `scripts/test-packages.sh`.*
- **The toolchain is pinned** — Xcode on major.minor, SwiftLint and SwiftFormat exactly — against
  README.md's Toolchain table. Bump the pins in `scripts/check-toolchain.sh` and the README table
  **in the same commit**, and re-run `scripts/ci.sh` on the new versions before pushing. —
  *enforcement: `scripts/check-toolchain.sh`, step 0 of every CI run.*
- No force unwrapping / force cast / force try in production code; tests may opt out on the line
  (`// swiftlint:disable:next force_unwrapping`), but prefer `try #require` / `XCTUnwrap`. —
  *enforcement: `.swiftlint.yml` (`force_unwrapping`, `force_cast`, `force_try` at error).*

## Process

- **One milestone = one branch** (`mX-*`), **one or a few conventional commits per task, in
  English; squashing is not required.** The earlier wording said "one commit per task", and no
  milestone has ever matched it: iOS-M1's tasks were multi-commit, and iOS-M2's ran 1-4 commits each
  (Task 1 took four — three independent library changes plus a script — and every review fix round
  added one). The reason to keep them separate is that a fix round's commit is the reviewable unit;
  squashing it into the feature commit hides what review changed. What is binding is that **each
  commit is a conventional commit that builds**, and that a task's commits are contiguous — not
  their count. Rewritten 2026-08-23 (iOS-M2 Task 8) to match the history instead of the other way
  round.
- **Linear history only.** Rebase onto `main`, fast-forward merge (`git merge --ff-only`). Never
  `--no-ff`, never a merge commit.
- Review before merge; `scripts/ci.sh` green is the entry ticket, not the finish line.
