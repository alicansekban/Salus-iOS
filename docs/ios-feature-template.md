# Salus iOS Feature Template

Reference implementation: **`Packages/Features/FeatureVitals`** (iOS-M2). Copy this structure when
creating a new feature package.

This file is the section-for-section twin of
`salus-android/docs/architecture/feature-template.md`. Where the two differ, the difference is the
platform, not a decision: each section names the Android construct it replaces. Every claim below
cites a file that ships today — if a citation and the code disagree, the code is right and this
file is stale.

Binding rules live in `CLAUDE.md`; this file shows the shape they produce.

---

## Package setup

There is no convention plugin twin — SwiftPM has none — so a feature manifest is written out in
full. Copy `Packages/Features/FeatureVitals/Package.swift` and change the name:

```swift
// swift-tools-version: 6.0                                   // never 5.x; Swift 6 language mode
import PackageDescription

let package = Package(
    name: "Feature<Name>",
    defaultLocalization: "tr",                                // TR is default AND fallback (spec §6.4)
    platforms: [.iOS(.v17), .macOS(.v14)],                    // macOS is a `swift test` host concession
    products: [.library(name: "Feature<Name>", targets: ["Feature<Name>"])],
    dependencies: [ /* core packages only, all `.package(path:)` */ ],
    targets: [
        .target(
            name: "Feature<Name>",
            dependencies: [ /* .product(name:package:) for each of the above */ ],
            resources: [.process("Resources")]                // the String Catalog
        ),
        .testTarget(
            name: "Feature<Name>Tests",
            dependencies: ["Feature<Name>", .product(name: "SalusTesting", package: "SalusTesting")]
        )
    ]
)
```

Reference: `Packages/Features/FeatureVitals/Package.swift` — tools version line 1,
`defaultLocalization` line 11, platforms line 14, the eight `.package(path:)` entries lines 18-27,
`.process("Resources")` line 41, the test-only `SalusTesting` dependency lines 44-50.

Four things the Gradle twin does implicitly and SwiftPM does not:

- **`SalusTesting` is a dependency of the *test* target only** — never of the library target. This
  is `testImplementation(projects.core.testing)`; putting it on the library ships `FixedSalusClock`
  into the app.
- **`.macOS(.v14)` is a test-host concession, not a target.** `swift test` cannot run a bundle on a
  simulator, so a package that reaches SwiftUI, GRDB or `Observation` also names macOS. iOS 17
  stays the ship target. `CLAUDE.md` lists the three qualifying reasons; do not add it for a fourth.
- **Features never depend on each other.** A `Feature*` manifest names core packages only. Cross-
  feature navigation is a shell callback (spec §4) — see *Navigation* below.
- **No new remote dependency.** The allowlist is closed at three (`CLAUDE.md`); a
  `.package(url:)` line in a feature manifest is a finding.

There is no `settings.gradle.kts` twin to edit, but there *is* an equivalent step: the app links
the package in `project.yml`, and `xcodegen generate` is run and both files committed in the same
commit (`project.yml` gained `FeatureVitals` in iOS-M2 Task 7).

## Directory structure

```
Packages/Features/Feature<Name>/
 └─ Sources/Feature<Name>/
     ├─ domain/          PURE SWIFT — no SwiftUI import, ported 1:1 from Kotlin
     │   ├─ model/       Domain models (WeightEntry.swift)
     │   ├─ repository/  Repository PROTOCOL (VitalsRepository.swift)
     │   └─ usecase/     Business rules — validation lives here (SaveWeightEntryUseCase.swift)
     ├─ data/            RepositoryImpl + Record↔Domain mappers.
     │                   GRDB records NEVER leave SalusDatabase; mappers are mandatory.
     │                   (VitalsRepositoryImpl.swift, WeightEntryMapper.swift)
     ├─ ui/<screen>/     Per screen: <Screen>UiState.swift (UiState + Event [+ Effect])
     │                   + <Screen>ViewModel.swift + <Screen>Screen.swift (Route + Screen)
     ├─ ui/<bridge>/     Optional: a system-framework bridge used by more than one screen
     │                   (M4's ui/calendar/ — CalendarEventDraft.swift + CalendarEventEditSheet.swift)
     ├─ navigation/      Hashable & Sendable keys + `func <name>Destinations() -> some View`
     ├─ Resources/       Localizable.xcstrings (tr source + en)
     ├─ <Name>Strings.swift    typed accessors over Bundle.module
     └─ <Name>Module.swift     the module factory (Koin module twin)
```

The `di/` directory of the Android template has no twin: there is no container, so the module is a
value at the package root (`VitalsModule.swift`) rather than a package of registrations.

Where Android puts `domain/` purity under a `salus.jvm.library` convention plugin, iOS relies on
review plus the SwiftLint custom rules — `no_ui_framework_in_domain` scopes to `SalusModel` and
`SalusCommon`, so a feature's own `domain/` is a review rule. A `import SwiftUI` under `domain/`
is a finding.

**A UIKit-only system framework is reached from `ui/` only, and always behind `#if canImport`.**
`swift test` builds a package for the *macOS host*, so a bare `import EventKitUI` (or any other
iOS-only framework) breaks every test run in the package even though the app target builds fine.
The rule M4 settled: keep the pure part framework-free and testable, and wrap the view part.

- The payload is a plain `Sendable` struct with static builders, in a file that imports nothing but
  `Foundation` — `ui/calendar/CalendarEventDraft.swift` — so `CalendarEventDraftTests` asserts it on
  the host with no framework in sight.
- The `UIViewControllerRepresentable` wrapper and every call site that mentions it sit inside
  `#if canImport(EventKitUI)` … `#endif` (`ui/calendar/CalendarEventEditSheet.swift:20`,
  `AppointmentDetailScreen.swift:86`, `AppointmentEditorScreen.swift:45`). What is left out on the
  host is the *button and the sheet*, never the state or the ViewModel behaviour.
- `domain/` and `data/` import no system UI framework at all, `#if` or not.

## UDF state types (in `<Screen>UiState.swift` — never `<X>Contract.swift`)

- **UiState**: one `struct`, `Sendable`, every property with a default in `init` so a screen can be
  previewed from `.init()`. Starts with `isLoading = true`. Lists are plain Swift arrays —
  `ImmutableList` has no twin and needs none: a Swift `struct`/`Array` is already a value type, and
  `@Observable` diffs by property access rather than by recomposition stability.
  Reference: `ui/list/VitalsUiState.swift:155` (`VitalsUiState`),
  `ui/editor/WeightEditorUiState.swift:9` (`WeightEditorUiState`).
- **Event**: an `enum`, `Equatable, Sendable` — user intents. Single entry point: `onEvent(_:)`.
  Reference: `ui/list/VitalsUiState.swift:195` (`VitalsEvent`),
  `ui/editor/WeightEditorUiState.swift:38` (`WeightEditorEvent`).
- **Effect**: an `enum` — one-shot **UI** work the screen must perform. **Never model navigation as
  an Effect**; a ViewModel navigates through the injected `Navigator`. Neither M2 screen has one,
  which is the expected default: add an Effect type only when there is real UI work to do.
  M3's `ReminderHealthEffect` is the first, and it settled how one is delivered: Kotlin's
  `Channel(BUFFERED, DROP_OLDEST)` + `receiveAsFlow()` has no `@Observable` twin, so the ViewModel
  publishes `private(set) var pendingEffect: Effect?` with a `consumeEffect()` that clears it, and
  the Route drains it from `.onChange(of: viewModel.pendingEffect)` — dropping the nil edge the
  clear itself produces. Reference:
  `Packages/Features/FeatureSettings/Sources/FeatureSettings/ui/reminderhealth/`
  (`ReminderHealthViewModel.swift`, `ReminderHealthScreen.swift`); the app layer's
  `ReminderOpenRouter` is the same shape one layer up.
  M4's `AppointmentEditorEffect.addToCalendar(CalendarEventDraft)` is the second and shows what
  qualifies: **presenting a system sheet is UI work, so it is an Effect; going to another screen is
  not, so it is a `Navigator` call** — the same ViewModel does both, and the delete path pops
  through the navigator while the calendar path publishes a `pendingEffect`
  (`ui/editor/AppointmentEditorViewModel.swift:30`, `:141-142`, `:223`; drained at
  `AppointmentEditorScreen.swift:79`).

ViewModel rules:

- `@MainActor @Observable public final class <Screen>ViewModel`
  (`ui/list/VitalsViewModel.swift:43-45`). `@Observable` replaces `StateFlow`; `state` is a plain
  stored property the view reads.
- **There is no `stateIn(WhileSubscribed(5_000))` twin.** `@Observable` has no subscription-count
  hook, so the DB observation starts in `init` (via `start()`, `VitalsViewModel.swift:79`, `:114`)
  and is cancelled in `deinit` (`:82`). The cancellation is held in a small box so a `deinit` — which
  cannot touch main-actor state — can still cancel it (`SalusCommon`'s `CancellationBox`).
- The DB is the single source of truth: the source is an `AsyncThrowingStream` from the repository,
  conflated with `.bufferingNewest(1)` (Room's `Flow` conflation).
- Inject `SalusClock` for time — never `Date()` in feature code (test determinism).
- Generate ids through `IdGenerator`.
- A stream that combines a DB stream with an `@Observable` (M2 combines history with
  `PendingDeleteController.pendingIds`) has no `combine` twin: re-register
  `withObservationTracking` after every change and re-publish
  (`VitalsViewModel.swift:189` and `:202`).
- **Two async streams are combined with `latestOfBoth`, the Kotlin `combine` twin.** M4 needed it
  three times over (repository, list VM, detail VM) so it exists as a real combinator rather than a
  hand-rolled pair of tasks per call site:
  `Packages/SalusCommon/Sources/SalusCommon/LatestOfBoth.swift`, which also carries `mapped`, the
  `Flow.map` twin a repository uses to map one DAO observation.
  It emits nothing until **both** sides have produced a value, fails the combined stream if either
  side fails, and — the property a hand-rolled version keeps getting wrong — holds its lock across
  *both* the transform and the yield, so a slow transform can never overwrite a fresher pair
  (`Packages/SalusCommon/Tests/SalusCommonTests/LatestOfBothTests.swift`, three cases). It lived in
  each feature's `data/` until iOS-M6 promoted it, with `mapped` and `CancellationBox`, to
  `SalusCommon` — the shape a helper takes once a third feature wants it. **Do not re-hand-roll
  one** — a ViewModel that combines two DB streams reuses this.
- **More than two streams: `latestOfThree` / `latestOfFour` / `latestOfFive`**
  (`Packages/SalusCommon/Sources/SalusCommon/LatestOfAll.swift`, added in iOS-M7 for the home
  dashboard). Each is a nesting of `latestOfBoth`, so the semantics above hold unchanged; they take
  no transform and answer a tuple in argument order, which the caller destructures or maps with
  `mapped`.
- **A non-throwing `AsyncStream` joins them through `throwingStream(over:)`**
  (`Packages/SalusCommon/Sources/SalusCommon/ThrowingStream.swift`). Settings and preferences
  observations do not fail, so they are the wrong concrete type for the combinators; the wrapper
  adds the error type and nothing else. Do not write a second combinator for that one shape.

## Shell and navigation-container rule (MANDATORY)

**There is exactly one `TabView` and one `NavigationStack` per tab in the app: the shell's.**
`App/RootView.swift:63` owns the `TabView`; `App/RootView.swift:121` builds the one
`NavigationStack` a tab gets, over the tab's own `NavigationPath` from `TabBackStacks`.

Feature screens:

- **NEVER declare a `NavigationStack`, `NavigationSplitView` or `TabView`.** A second navigation
  container re-applies the safe area and pushes the title bar down — the exact twin of Android's
  double-Scaffold bug.
- **NEVER call `.ignoresSafeArea`, `.safeAreaInset` or a status/home-bar padding hack.** Insets are
  consumed in one place.
- If a title bar is needed, use `.navigationTitle(_:)` + `.toolbar { }` on the screen's own body —
  the shell's stack renders them (`ui/editor/WeightEditorScreen.swift:82-83`).
- If a FAB is needed, `ZStack(alignment: .bottomTrailing)` + `.padding(16)`
  (`ui/list/VitalsScreen.swift:72-73`, whose comment names the rule).
- Screen roots start with `.frame(maxWidth: .infinity, maxHeight: .infinity)`.

The snackbar host is the shell's too, and there is exactly one
(`App/RootView.swift:102` + `:114`): a feature raises a request through `SalusSnackbarController`
and never mounts a host.

**The tab bar is the shell's: it shows only on a tab's root and is hidden on every pushed
destination; a feature never sets `.toolbar(…, for: .tabBar)` itself** (`App/RootView.swift`, the
twin of Android's `showBottomBar` in `SalusApp.kt:133-136`). `RootView.tabStack(for:)` applies
`.toolbar(backStacks.isAtRoot(tab) ? .visible : .hidden, for: .tabBar)` to the tab's
`NavigationStack`, so a detail, an editor or any future pushed screen gets the full height without
writing a line — and a screen that sets the modifier itself is a finding, because it would fight the
shell rather than inherit it. That finding is mostly mechanical: the SwiftLint custom rule
`no_tab_bar_toolbar_in_features` (severity: error, `included:` scoped to `Packages/Features/`,
fixture-checked by `scripts/lint-custom-rules.sh`) fails the build on a single-line
`.toolbar(…)` or `.toolbarVisibility(…)` call in a feature package whose arguments name
`.tabBar` — including a variadic placement list such as
`.toolbar(.hidden, for: .navigationBar, .tabBar)`, which is the spelling a full-screen screen
reaches for. It is a regex, so it is not exhaustive: a call hand-wrapped across lines, or a
placement reached through a variable (`let p: ToolbarPlacement = .tabBar`), still passes the linter
and is still a finding. The rule catches the accident; the rule above is what binds.

Reference: `VitalsScreen` (ZStack + FAB) and `WeightEditorScreen` (VStack + toolbar).

### Gates are overlays, never destinations

The app-lock and onboarding gates are **overlays above the `TabView` and outside every
`NavigationStack`** — not nav destinations and not an `if/else` swap of the whole shell. This is
the iOS twin of the Compose gate order in `MainActivity.kt:47-107`, and it is what keeps the back
stack and any pending notification deep link alive behind a gate: an overlay neither pushes nor
pops anything, so memoised pushes (the `D-M7-ab` cycle-calendar depth, the appointments twin) still
mean what they meant while a gate is up.

- The two gates draw as **siblings in a `ZStack` in Android's z-order — later is on top**, so the
  lock covers the app and onboarding covers the lock (`App/RootView.swift:120-144`). They are not
  exclusive: a reinstall keeps `app_lock_enabled` (it lives in the Keychain) while clearing
  `onboarding_completed`, and a real device can want both at once.
- Onboarding sits **outermost** — a first launch has nothing to lock (Android's comment verbatim,
  `MainActivity.kt:96-98`, plan ruling 3). The gate order and the "which covers which" flags live
  in `App/RootGates.swift`, extracted so the logic is readable on its own.
- A gate has no stack to pop, so it draws **no back affordance from the shell** and the
  shell-drawn-back precedent does not hold for it: the onboarding gate draws its own back chevron
  (iOS-M8, divergence (d) / H-8). A feature is never involved — these are shell overlays.
- The secure screen is a curtain over the `TabView` and outside every `NavigationStack` too
  (`RootView`'s `.secureScreen(maskingEnabled:)`), drawn above all three gates so the blur and the
  mask cover them as well.

**Shell logic lives in `SalusCommon`, with the shell injecting it** — the `PendingDeleteController`
precedent (`@Observable`, iOS-M1) now joined by `AppLockManager` (iOS-M8). Both are pure state
machines with no UI framework and no app target, and the app target has no test bundle
(`project.yml`'s `scheme.testTargets: []`), so logic that deserves a case-for-case test suite lives
in `SalusCommon` where `swift test` can reach it; the shell owns only the two things that *are*
platform — the `scenePhase` forwarder in `SalusApp` and the `LAContext` prompt in `App/Lock/`.
`SalusCommon` stays UI-free (its `@Observable` is Observation, not SwiftUI), so this is a layering
choice, not a domain-layer exception.

Reference: `App/RootGates.swift`, `App/Lock/AppLockGate.swift`, `App/RootView.swift:120-170`.

## Route / Screen split

- **`<Name>Route`**: `public`, stateful. It reads the feature's module from the environment
  (`@Environment(\.vitalsModule)`), builds the ViewModel once inside `.task`, holds it in `@State`,
  and draws a `ProgressView` until it exists. Click-driven navigation goes through
  `module.navigator`. Only *cross-feature* navigation arrives as a closure parameter
  (`onOpenTrends`). Reference: `ui/list/VitalsScreen.swift:23-73`.
- **`<Name>Screen`**: **internal, not public** — stateless: `state` + `onEvent` + nav callbacks
  only, so it is `#Preview`-able and testable without a ViewModel. Nothing outside the package
  needs it; the shell only ever names the Route. Reference: `ui/list/VitalsScreen.swift:76`,
  `ui/editor/WeightEditorScreen.swift:54`.

`koinViewModel()` has no twin, and the missing one matters: SwiftUI has no per-destination
ViewModel store, so **the Route owns the ViewModel in `@State`** and a pushed destination gets a
fresh one because SwiftUI builds a fresh Route. A parameterised ViewModel
(`koinViewModel { parametersOf(id) }`) is a factory call with the argument —
`module.makeWeightEditorViewModel(entryId)`.

## Navigation (keys, `…Destinations()`, `Navigator`)

```swift
// navigation/<Name>Navigation.swift
public struct <Name>Key: Hashable, Sendable { public init() {} }        // the tab root, if it is one
public struct DetailKey: Hashable, Sendable { public let id: String? }

public extension View {
    /// Every destination this feature owns. The shell applies it to the tab's NavigationStack.
    func <name>Destinations() -> some View {
        navigationDestination(for: DetailKey.self) { key in DetailRoute(id: key.id) }
    }
}
```

Reference: `navigation/VitalsNavigation.swift:21` (`VitalsKey`), `:26` (`WeightEditorKey`), `:48`
(`vitalsDestinations()`); mounted at `App/RootView.swift:123-135`.

- `EntryProviderScope<NavKey>.<name>Entries()` becomes a **`View` modifier**. Both keep every key
  inside the feature that owns it: the shell names none of them, it applies the modifier.
- **`@Serializable` has no twin, and the keys are not `Codable`.** Navigation 3 serialises keys to
  survive process death; a `NavigationPath` only serialises entries appended through its
  `Codable`-constrained overload, and nothing restores a path yet. `Hashable` is what
  `navigationDestination(for:)` actually requires.
- **`AnyNavKey` carries an `append` closure that appends the *concrete* key**
  (`Packages/SalusNavigation/Sources/SalusNavigation/AnyNavKey.swift:23-29`, iOS-M2 Task 1). That
  one line is why a feature can keep owning its destinations instead of the app target needing a
  central `navigationDestination(for: AnyNavKey.self)` switch — the M1 deferred finding this
  milestone closed.
- **Navigating within a feature goes through `Navigator`** (`SalusNavigation`), injected into the
  ViewModel for outcome-driven moves (`pop()` after a successful save) or reached through the
  module in the Route for click-driven ones. The back stack belongs to the app
  (`TabBackStacks`); the `Navigator` only publishes commands the shell applies.
- **Navigating to another feature's key is impossible by construction** — that is the point. Those
  stay closures the shell fills in, because only the shell sees every key.
- The stack's own back button pops the same `NavigationPath` that `Navigator.pop()` mutates, so a
  screen never draws its own back arrow and never takes an `onBack` parameter.

## Module factory

Koin's `module { }` is a description a container resolves per call site. There is no container
(`CLAUDE.md`: "the composition root owns the singletons"), so the module is a **value the
composition root builds once and hands down**:

```swift
@MainActor
public struct <Name>Module {
    public let repository: any <Name>Repository                       // single<XRepository>
    public let navigator: Navigator
    public let makeSomeUseCase: @MainActor () -> SomeUseCase          // factoryOf(::SomeUseCase)
    public let makeListViewModel: @MainActor () -> ListViewModel      // viewModelOf(::ListViewModel)
    public let makeDetailViewModel: @MainActor (String?) -> DetailViewModel  // viewModel { params -> }
}

@MainActor public func make<Name>Module(…) -> <Name>Module { … }      // every dependency passed in

extension EnvironmentValues {
    @Entry public var <name>Module: <Name>Module?                     // how the Routes reach it
}
```

Reference: `VitalsModule.swift:32-51` (the three Koin scopes and their twins are documented at
`:1-19`), `:58` (`makeVitalsModule`), `:115` (the `@Entry`). Built in
`App/AppCompositionRoot.swift:113`, injected on the **stack** in `App/RootView.swift:135` — not
inside its root view, or a pushed destination would not see it.

- The environment value is **optional** because `@Entry` needs a default and there is no honest
  one: a module built from nothing would be a second, silent object graph. A Route that finds `nil`
  draws its spinner, so a dropped injection looks like a dropped injection.
- `KoinModulesTest` has no twin — there is no graph to verify, because the compiler checks it: an
  unbuilt dependency is a missing initialiser argument.
- A type that the app also needs by protocol (Kotlin's `bind VitalsQuickEntry::class`) needs no
  second registration; the composition root exposes it as a computed property over the same factory
  (`AppCompositionRoot.swift:86`).

## Testing standard

| What | How |
| --- | --- |
| UseCase | Pure Swift Testing; `Fake<X>Repository` in the test target (`Tests/…/FakeVitalsRepository.swift`) |
| ViewModel | `@MainActor` suite + fake repo + `FixedSalusClock` + `FakeNavigator`; there is no Turbine — poll the `@Observable` `state` with the local `waitUntil` helper (`Tests/…/WaitUntil.swift`) |
| Mapper | Input/output equality, pure test (`WeightEntryMapperTests.swift`) |
| DAO | Lives in `SalusDatabase`, not in the feature: add feature-specific queries and their tests there (`VitalsDaoTests.swift`) |
| Repository impl | In-memory `SalusDatabase.inMemory()` round trip (`VitalsRepositoryImplTests.swift`) |
| Views | `#Preview` build only — there is no Compose-UI-test twin in the gates; behaviour lives in the ViewModel where it can be asserted |

- **`MainDispatcherRule` has no twin.** `@MainActor` on the suite is the whole mechanism.
- **`Navigator` is a concrete `final class`, not a protocol.** The fake is a real `Navigator`
  instance whose `NavCommand` stream the test records (`Tests/…/FakeNavigator.swift`) — do not
  introduce a protocol for it.
- **The Android test table is the drift detector**: port it case-for-case, by name. A ported type
  without its ported table is an unfinished port. A table that exists only on iOS is an Android gap
  — open it in `salus-android/docs/ios-v1-plan.md` §11 in the same milestone.
- **Manual QA is written, not run, by the agents who build a milestone** (user decision,
  2026-08-30). Anything that needs a tap, a real clock or the OS's own stores goes into
  `scripts/m<N>-manual-qa.md` as a numbered step with an expected result, and the user runs it. A
  milestone's implementers run `scripts/test-packages.sh`, `scripts/build-app.sh` and
  `scripts/ci.sh` only. A step nobody has executed says **NOT RUN** in that file — never "passing".
- `scripts/test-packages.sh <PackageName>` narrows the run; `scripts/ci.sh` is the gate.
- After adding **or deleting** a *file* in a path dependency, a warm checkout can fail with a stale
  `Packages/*/.build` — "missing inputs" for a file that is no longer there is the same stale-cache
  failure as an unseen new one, and M4's Task 1 hit it by *moving* `LocalDateTime` out of
  `FeatureVitals`. Run `scripts/clean.sh`.

## Days and dates

A *day* is `SalusModel.LocalDate` and travels as `epochDay`; a `Date` is an absolute instant only.
The rule and its three carve-outs are in `CLAUDE.md` — what changed in iOS-M7 is the enforcement:

- **This is now mechanical.** `.swiftlint.yml`'s `no_calendar_outside_clock` custom rule (error,
  `included:` the whole tree) rejects a `Calendar` construction, `Calendar.current` /
  `Calendar.autoupdatingCurrent`, and a `Calendar` type position, everywhere except the three
  sanctioned files and the two tests that exercise them. `scripts/lint-custom-rules.sh` proves it
  fires — its fixture asserts an exact hit count *and* silence on all five carve-out files, because
  a custom rule's `included:`/`excluded:` fails as silently as its regex does.
- It cannot see indirection (a `typealias`, a stored property, `NSCalendar`), so review is still the
  backstop. Formatting a day in a feature goes through `LocalDate.formatted(pattern:locale:)`;
  formatting an instant goes through `Date.FormatStyle` with an explicit locale *and* time zone.

## Charts

**Features NEVER import Charts.** Use `ChartUiModel` + `SalusLineChart` from `SalusUI`; the x axis
is epoch-day, and conversion/downsampling happens in the ViewModel
(`VitalsViewModel.dailyPoints` / `chartOrNull`).

- `ChartPoint(xEpochDay: Int, y: Float)`,
  `ChartUiModel(points:xLabel:yLabel:secondaryPoints:)` with `@Sendable` label closures —
  `Packages/SalusUI/Sources/SalusUI/chart/ChartUiModel.swift:17`, `:35`.
- `SalusLineChart(model:lineColor:contentDescription:)` —
  `Packages/SalusUI/Sources/SalusUI/chart/SalusLineChart.swift:28`.
- **This is mechanical**: `.swiftlint.yml`'s `no_charts_in_features` custom rule (error,
  `included:` scoped to `Packages/Features/`) rejects `import Charts` in any form —
  scoped, `@preconcurrency`-prefixed — and `scripts/lint-custom-rules.sh` proves the rule fires by
  planting a fixture inside the scope and an identical one outside it. Both run in `scripts/ci.sh`.
- Never lint with `swiftlint --path`: it silently disables the custom rules.

### Material → SwiftUI mappings this slice settled

Recorded so nobody re-improvises them. Full tables in the iOS-M2 task 3 and task 6 reports, and
the iOS-M4 task 6, 8 and 9 reports for the rows marked *(M4)*.

| Android | iOS |
| --- | --- |
| Vico `CartesianChartHost` + `CartesianChartModelProducer` | Swift Charts `Chart { }` — the marks *are* the data, so the producer and its `LaunchedEffect` disappear |
| `LineCartesianLayer` + `AreaFill` + `Brush.verticalGradient` | `LineMark` + `AreaMark` + `LinearGradient` |
| `CartesianValueFormatter` | `AxisMarks { AxisValueLabel { … } }` calling `model.xLabel` / `model.yLabel` |
| `SingleChoiceSegmentedButtonRow` (one of N, a range selector) | `Picker(…).pickerStyle(.segmented)` with an **empty** label |
| `FilterChip` (multi-select, M4's reminder offsets) *(M4)* | `SalusUI.SalusFilterChip(label:isSelected:action:)` — `secondaryContainer` fill when selected, outline when not, 48 pt minimum touch target, Dynamic-Type-scaled |
| `AssistChip` / status pill *(M4)* | `SalusUI.SalusStatusChip(label:accent:)`, tinted from a `FeatureAccent?` |
| `SalusSectionHeader` (core/ui) *(M4)* | `SalusUI.SalusSectionHeader(title:)`, or `SalusSectionHeader(title:actions:)` with a `@ViewBuilder` trailing closure for the optional trailing action — `titleLarge` / `onSurface`. A *group label* inside a form is **not** this: it is a plain `Text` at `titleSmall` / `onSurface` |
| `SalusPillButton` (core/ui) *(M4, superseded by M6/M7)* | `SalusUI.SalusPillButton` — `.buttonStyle(.plain)` over a hand-drawn `SalusShapes.pill`, 48-pt label floor, Material's disabled alphas, `fillsWidth`. The M4 row said "there is no `SalusPillButton` view; use `.borderedProminent`/`.bordered`": iOS-M6 built the component (a system button style cannot be held to the 48-pt token) and **iOS-M7 migrated the last four inline copies** (appointment detail ×4 including the maps pill, medication detail ×2, `SalusEmptyState`). Do not hand-roll a fifth |
| `DatePickerDialog` over an `epochDay` *(M4)* | `SalusUI.SalusDateField(title:epochDay:placeholder:seedEpochDay:onChange:)` — the binding converts on the GMT boundary, never `Calendar.current`; `nil` draws a placeholder button that opens the wheel at `seedEpochDay` and **commits nothing** until the wheel actually moves, the twin of `SalusTimeField` below |
| `TimePickerDialog` over a `minuteOfDay` *(M4)* | `SalusUI.SalusTimeField(title:minuteOfDay:placeholder:seedMinuteOfDay:onChange:)` — `nil` draws a placeholder button and **commits nothing** until the wheel actually moves, which is how a Compose dialog's Cancel behaves; `seedMinuteOfDay` is required so the caller, not the component, owns the Kotlin `?: 9` default |
| `kotlinx.datetime.LocalDateTime` *(M4)* | `SalusModel.LocalDateTime` (`LocalDate` + `minuteOfDay`), with `isoLocalString` / `init?(isoLocalString:)` writing exactly what Kotlin's `toString()` writes, and `instant(in:)` in `SalusCommon/SalusClock.swift`. It moved out of `FeatureVitals` the moment a second feature needed it — do not copy it into a feature |
| `Intent(ACTION_INSERT, CalendarContract.Events.CONTENT_URI)` *(M4)* | `EKEventEditViewController` in a `UIViewControllerRepresentable`, prefilled and confirmed by the user. The system sheet carries its own calendar chooser, so nothing replaces the chooser Android's intent picker gave you — and on iOS 17+ it needs **no** usage description and raises **no** permission prompt (measured on a simulator, iOS-M4 task 8) |
| `Intent(ACTION_VIEW, "geo:0,0?q=…")` *(M4)* | `URL(string: "maps://?q=" + query)`; `Uri.encode` is `addingPercentEncoding(withAllowedCharacters: .salusUriEncodeAllowed)` — unreserved characters only. **Never `.urlQueryAllowed`**, which leaves `& + = ? ; / ,` alone and truncates a clinic named "Smith & Sons" at the ampersand |
| `LazyColumn` + `contentPadding` | `ScrollView` + `LazyVStack` + `.padding` |
| `CircularProgressIndicator` | `ProgressView()` |
| `TopAppBar` | `.navigationTitle(_:)` + `.toolbar { ToolbarItem(placement: .primaryAction) }` |
| `navigationIcon` back arrow | the stack's own back button (see *Navigation*) |
| `OutlinedTextField` (+ `suffix`, `isError`/`supportingText`, `minLines`) | `TextField(…).textFieldStyle(.roundedBorder)`; a trailing `Text` in an `HStack`; an error-role `Text` under the field; `axis: .vertical` + `.lineLimit(2...6)` |
| `AlertDialog` | `.salusConfirmDialog(isPresented:)`, confirm button `role: .destructive` |
| `Icons.Filled.*` (`ImageVector`) | SF Symbol **names** (`systemImage: String`) |
| `Modifier.semantics { contentDescription }` | `.accessibilityElement(children: .ignore)` + `.accessibilityLabel` |
| `Modifier.weight(1f)` in a `Row` | `.frame(maxWidth: .infinity, alignment: .leading)` in an `HStack` |
| `Column`/`Row` default arrangement | `VStack`/`HStack` with an **explicit** `spacing: 0` |
| `CardDefaults.cardElevation` | `.salusShadow(.card, isDark:)` — no shadow in dark (`design-tokens.md` §7) |
| `String.format(locale, "%d", int)` | `String(format: "%lld", locale:, …)` — Swift's `Int` is 64-bit |
| `DateTimeFormatter.ofPattern(p, locale)` | `DateFormatter` with a **fixed** `dateFormat`, never `setLocalizedDateFormatFromTemplate` (which reorders components per region where Android does not) |
| `koinViewModel()` / `koinInject<Navigator>()` | `@Environment(\.<name>Module)` + a factory called from `.task` |

**A tappable control is never nested inside `SalusCard(onTap:)`.** Compose lets a clickable child
inside a clickable `Card` win the gesture; SwiftUI's `SalusCard(onTap:)` is a `Button`, and anything
in a `Button`'s label is part of the label — the inner tap is swallowed and VoiceOver reads one
element. So a card's own pill or icon button is a **sibling**: the card's tappable region and the
control sit side by side in the same `HStack`, each with its own accessibility element. This is the
house pattern (`VitalsRow`, `MedicationCard`, `AppointmentsScreen`, and iOS-M7's Home dose and
appointment cards); the Android twin nests, which is Android follow-up `A32`.

Design values come only from `salus-android/docs/design/design-tokens.md` through
`SalusDesignSystem`; a view reads the theme from `@Environment(\.salusTheme)` and never takes a
`theme:` parameter.

## Strings

**This section has no Android twin**, exactly as the `di/` directory and `koinViewModel()` have no
iOS twin above: `salus-android/docs/architecture/feature-template.md` says nothing about strings,
because on Android a `strings.xml` pair *is* the whole mechanism and needs no template. The iOS
side needs one — catalog layout, the typed accessor, the placeholder remapping and the `swift test`
trap are all port-specific — so it is written here and the "section-for-section twin" claim at the
top is one section short in this direction. The same is true of **Material → SwiftUI mappings this
slice settled** under `## Charts`: a mapping table exists only for the platform being mapped *to*.

Android's `res/values/strings.xml` + `values-en/strings.xml` become **one String Catalog per
package**: `Sources/Feature<Name>/Resources/Localizable.xcstrings`, `tr` as the source language,
`en` as the only other locale.

- Port key **name and text verbatim** from the XML. No new copy is invented in the port.
- Access strings through a typed `enum` over `Bundle.module`
  (`VitalsStrings.swift:35` and its accessors) — never a bare `String(localized:)` at a call site,
  because the key would then resolve against the *main* bundle and silently return itself.
- **Placeholder mapping is the one place the port is not byte-for-byte**: `%1$s` → `%1$@` (a Swift
  `String` under `%s` reads a C pointer) and `%1$d` → `%1$lld` (Swift's `Int` is 64-bit). The
  sentence around the specifier is unchanged. Documented at `VitalsStrings.swift:6-22`.
- `SalusUI` owns its own catalog for the shared strings (`SalusUIStrings.swift`); a feature never
  reaches into another package's bundle.
- A snackbar request carries an **already-localised `String`**, not a key: the host is mounted in
  the shell and a feature's strings live in its own `Bundle.module`.
- **Preview and accessibility copy uses `Text(verbatim:)`.** `Text("…")` with a literal takes a
  `LocalizedStringKey`, and Xcode's string extraction writes every one it finds in a package into
  that package's `Localizable.xcstrings` — which is how a stray `"Host"` and an empty key landed in
  `SalusUI`'s catalog during the M2 simulator pass and broke its key-set pin. If the text is not
  meant to be translated, it must not look like a key.
- **A delete goes through `UndoableDelete`, and its snackbar dies with the undo window.** The
  request is built with `duration: .milliseconds(PendingDeleteController.undoWindowMillis)`, so the
  timeout is derived from the window rather than repeating the number; a feature never sets a
  snackbar duration for a delete itself. Every *other* action snackbar keeps Material's default
  (`.indefinite`) and is dismissed by tapping it.

**Both string rules are mechanical**, from `SalusTesting`:

- `StringCatalogParity` — `assertSourceLanguage` (tr), `assertKeys(of:are:)` (a literal key-set
  pin copied from the XML), `assertEveryKeyIsLocalized` (both locales present, non-empty, and no
  third locale). Per-package usage: `Tests/FeatureVitalsTests/VitalsStringsTests.swift:274`,
  `:283`, `:302`, `:311`.
- `BannedHealthClaims.assertCatalogsNameNothingBanned(paths:)` and
  `assertSourcesNameNothingBanned(roots:exemptFileNames:)` — run repo-wide from
  `Packages/SalusTesting/Tests/SalusTestingTests/BannedHealthClaimsTests.swift:68` ("no Swift source
  in the repository names anything banned") and `:79` ("no string catalog in the repository names
  anything banned"). Both fail loudly if the scan reaches zero files.

**Toolchain trap, and it costs an hour to rediscover:** a `.xcstrings` is compiled into
`.lproj/Localizable.strings` by **Xcode's** build system only. `swift build` / `swift test` copies
the catalog verbatim, so a lookup under `swift test` finds no table and `String(localized:)`
returns the key. That is why the tests assert against the **file**, never against a resolved
string; the end-to-end check is the simulator run
(`Packages/Features/FeatureVitals/Sources/FeatureVitals/VitalsStrings.swift:24-31`).
