---
paths:
  - "**/App/**"
  - "**/Packages/**"
  - "**/project.yml"
---
# Salus iOS architecture rules (MANDATORY)

Settled decisions, layer rules and port-fidelity rules. Every rule names its **enforcement point**
(a lint rule, a test, or "review"); a rule with no mechanism is still binding. Global rules are in
`CLAUDE.md`.

## Settled decisions (do not relitigate)

- **The dependency allowlist is closed and is exactly three** (spec §3), each arriving with the
  milestone that needs it and never before: **GRDB** (iOS-M1/M2 persistence), **`purchases-ios`**
  (RevenueCat, premium), **`firebase-ios-sdk`** (FirebaseAI + FirebaseAppCheck, AI). Charts, PDF,
  crypto and biometrics come from the system. Nothing else is ever added, and the allowlist stays
  closed at three. The tree today has **exactly two** remote SPM dependencies: **GRDB.swift**,
  pinned `from: "7.11.1"`, declared in `Packages/SalusDatabase/Package.swift` (arrived with
  iOS-M1), and **`purchases-ios`**, pinned `from: "5.87.1"`, declared in
  `Packages/SalusPremium/Package.swift` (arrived with iOS-M9). The other 22 manifests still
  declare `dependencies: []` or local `.package(path:)` entries only; the app reaches GRDB
  transitively, by linking `SalusDatabase`, and `purchases-ios` transitively, by linking
  `SalusPremium`. A third `.package(url:)` line anywhere is a finding unless it is
  `firebase-ios-sdk` arriving with its own milestone. — *enforcement: review of every
  `Package.swift` / `project.yml` diff.*
- Offline-first, local-only: no backend of ours, no analytics, no ad-hoc networking. The
  Android carve-outs (store billing, Firebase AI) arrive with their own milestones and
  nowhere else. — *review.*
- Deployment target **iOS 17**; bundle identifier **`com.alicansekban.salus`** (matches the
  Android `applicationId` — RevenueCat needs the two to be one project). The app ships from
  `Salus.xcodeproj`.
- **Swift 6 language mode everywhere, strict concurrency from day one**: `SWIFT_VERSION: "6.0"`
  in `project.yml` and `// swift-tools-version: 6.0` in all 25 manifests. Never downgrade a
  target to Swift 5 mode (`swiftLanguageMode(.v5)`) to silence a `Sendable` error — fix the
  model instead. — *enforcement: `project.yml` + the manifests; a downgrade is visible in the
  diff.*
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
    Gregorian calendar in the reminder's zone. **Two files for instant↔day computation,
    `SalusClock.swift` and `UserNotificationGateway.swift`, and no third**: a `Calendar` that
    computes, shifts or compares a day anywhere else in the tree is the finding this rule is for.
    Recorded here in iOS-M4 because both files used to call themselves the last one.
  - **A `Calendar` may also be read for *localized symbols only*, in exactly one place:**
    `Packages/SalusUI/Sources/SalusUI/component/SalusWeekdaySymbols.swift` (iOS-M6), which answers
    the seven narrow weekday letters a calendar grid heads its columns with — Kotlin gets them from
    `DayOfWeek.getDisplayName(TextStyle.NARROW, locale)` and Foundation has no `DayOfWeek`. The
    carve-out is narrow on purpose: a fixed `Calendar(identifier: .gregorian)` with the *caller's*
    `locale` set (never `Calendar.current`, which follows the device's region and would answer
    another calendar's week), reading a static symbol table and **never touching a `Date`** —
    nothing there computes or shifts a day. A view passes its `@Environment(\.locale)`. A second
    symbol helper, or a `Date` inside this one, is the finding. — *enforcement: `.swiftlint.yml`
    custom rule `no_calendar_outside_clock` (severity: error), landed in iOS-M7. Its `included:` is
    the whole tree (`App/.*\.swift`, `Packages/.*\.swift`) minus an `excluded:` list of exactly
    the three sanctioned files plus the two test files that build a `Calendar` to exercise them
    (`SalusWeekdaySymbolsTests.swift`, `UserNotificationGatewayTests.swift`). It matches a
    construction (`Calendar(`), the device calendar in both spellings (`Calendar.current`,
    `Calendar.autoupdatingCurrent`) and a type position (`-> Calendar`, `: Calendar`), while
    leaving identifiers that merely contain the word alone (`UNCalendarNotificationTrigger`,
    `CycleCalendarBuilder`, `addToCalendar`). Proven to actually fire by
    `scripts/lint-custom-rules.sh`, whose planted fixture holds a construction, an
    `autoupdatingCurrent` and a decoy line of those three identifiers, and which asserts — in one
    repo-wide run — that the rule fires on it exactly twice and stays silent on all five carve-out
    files. The exact count is what keeps the substring guard mechanical; the five silences are the
    measurement that `excluded:` is honoured on a *custom* rule, rather than an assumption about
    it. Plus `SalusUITests/SalusWeekdaySymbolsTests.swift`, and review for what a regex cannot see
    (a `Calendar` reached through a `typealias` or a stored property, or the ObjC `NSCalendar`).*
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
  25. A new module on either platform gets its twin on the other, with the same name shape. —
  *review; `scripts/test-packages.sh` discovers packages by manifest, so a new one is tested
  automatically.*
- **`.macOS(.v14)` in a manifest is a test-host concession, not a target.** `swift test` cannot
  run a bundle on an iOS simulator, so a package whose host build cannot succeed under
  `[.iOS(.v17)]` alone also declares `.macOS(.v14)`. **iOS 17 remains the ship target** and never
  ship-conditions on macOS. There are exactly three reasons a package qualifies, and 22 of the 25
  do:
  - **Reaches SwiftUI** — directly (`SalusDesignSystem`, and `SalusNavigation` since its
    `TabBackStacks` holds one `NavigationPath` per tab) or transitively (`SalusUI` and the ten
    feature packages). Thirteen packages.
  - **Reaches GRDB** — `SalusDatabase`, plus its dependents `SalusProfile`, `SalusAI`,
    `SalusReminder`, `SalusSmoking`. Five packages. GRDB's own manifest declares a macOS 10.15 floor; a manifest
    that names no macOS platform is read by SwiftPM as macOS 10.13, and the host build fails with
    *"the library 'SalusDatabase' requires macos 10.13, but depends on the product 'GRDB' which
    requires macos 10.15"*. The floor propagates, so every future package that links
    `SalusDatabase` inherits the concession — that is expected, not a smell.
  - **Reaches `Observation`** — `SalusCommon`, whose `PendingDeleteController` is `@Observable`
    (iOS 17 / macOS 14; the host build otherwise fails with *"'Observable()' is only available in
    macOS 14.0 or newer"*), plus its dependents `SalusSettings` and `SalusTesting`, and
    `SalusPremium` (its `PremiumRepositoryImpl` is `@Observable`, arrived with iOS-M9). Four
    packages. `Observation` is not a UI framework, so the domain-layer rule
    below still holds — this is the same host-build mechanics as the two above, not an exception
    to it.

  The remaining three — `SalusModel`, `SalusBackup`, `SalusNotifications` — stay `[.iOS(.v17)]`
  alone; do not add `.macOS` to a package that does not need it, and never add it to silence
  something other than these three. (`SalusPremium` left this list in iOS-M9: it gained
  `.macOS(.v14)` because its `PremiumRepositoryImpl` is `@Observable` — the "Reaches `Observation`"
  reason above — while `purchases-ios` declares a macOS 10.15 floor.) — *enforcement:
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
- **Every persisted key and value string is Android-verbatim** (spec §9): the 15 settings keys
  (`onboarding_completed`, `app_lock_enabled`, `secure_screen_enabled`, `theme_mode`,
  `premium_theme`, `glucose_unit`, `cycle_reminder_enabled`, `cycle_reminder_lead_days`,
  `cycle_reminder_minute_of_day`, `paywall_intro_shown`, `ai_free_summary_used`,
  `ai_calls_count`, `ai_calls_epoch_day`, `home_open_count`, `review_last_requested_ms`) and
  every enum raw value stored under them
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
  of `salus-android/core/database/schemas/com.alicansekban.salus.core.database.SalusDatabase/…`, and `RoomSchemaParityTests` reads them to prove the GRDB
  migrations produce Android's tables, columns and indices. A schema change on either platform means
  re-copying the JSON for the new version **in the same commit** as the migration. — *enforcement:
  `RoomSchemaParityTests`, which fails the moment the two schemas diverge.*
