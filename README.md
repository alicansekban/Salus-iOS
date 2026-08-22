# Salus iOS

Native Swift/SwiftUI port of [Salus Android](https://github.com/alicansekban/Salus-Android) —
full parity: health tracking, premium, AI summary, doctor report (PDF), advanced trends.

## Source of truth

The port contract lives in the Android repository and is versioned there:

- `salus-android/docs/ios-v1-plan.md` — the 14-milestone plan (iOS-M0…M13), platform decisions,
  behaviour constants, settings keys.
- `salus-android/docs/design/design-tokens.md` — 213 design tokens, each with its Kotlin source
  line and SwiftUI equivalent; `SalusDesignSystem` transcribes this file, it does not invent.
- `salus-android/docs/contracts/backup-format-v1.md` — cross-platform encrypted backup format
  (DRAFT; gates iOS-M12 only).

The guarding rule of the port: domain logic is hand-ported 1:1 from Kotlin with the Android
table-tests carried over as the drift detector. Behaviour differences are only the ones decided
and recorded in the plan (§6).

## Milestone plans

Per-milestone execution plans live in `docs/plans/` in this repository.

## Toolchain

Host tooling required to build this project. The three command-line tools are installed with
Homebrew (`brew install xcodegen swiftlint swiftformat`); they are build/host tooling, not
project dependencies.

| Tool | Version | Purpose |
| --- | --- | --- |
| Xcode | 26.4.1 (build 17E202) | Swift compiler, SDKs, simulators |
| XcodeGen | 2.46.0 | Generates `Salus.xcodeproj` from `project.yml` |
| SwiftLint | 0.65.0 | Lint |
| SwiftFormat | 0.62.1 | Formatting |

Verify all three with:

```sh
xcodegen --version && swiftlint version && swiftformat --version
```

The versions above are pinned, and `scripts/check-toolchain.sh` asserts them on every CI
run and every local `scripts/ci.sh`. Xcode is matched on **major.minor** (any 26.4.x
passes — the patch changes neither Swift's language rules nor the targeted SDKs, and
GitHub rotates its image Xcode patches on its own schedule); SwiftLint and SwiftFormat are
matched **exactly**, because `swiftlint --strict` runs on a zero-warning budget and a patch
release can add rules. The pins live at the top of that script — bump them and this table
in the same commit.

## Dependencies

The dependency allowlist is closed and is exactly three (`CLAUDE.md`), each arriving with the
milestone that needs it. One of the three has arrived:

| Dependency | Version | Declared in | Why |
| --- | --- | --- | --- |
| [GRDB.swift](https://github.com/groue/GRDB.swift) | `from: "7.11.1"` (resolved 7.11.1) | `Packages/SalusDatabase/Package.swift` | SQLite persistence — the twin of Android's Room layer (iOS-M1/M2) |

The remaining two, not yet added: `purchases-ios` (RevenueCat, premium) and `firebase-ios-sdk`
(FirebaseAI + FirebaseAppCheck, AI). Charts, PDF, crypto and biometrics come from the system.

`SalusDatabase` is the only package that names GRDB; the other 23 manifests declare
`dependencies: []` or local `.package(path:)` entries only, and the app reaches GRDB
transitively by linking `SalusDatabase`. Two resolution files are committed so a clean clone and
a CI run build the reviewed revision: `Packages/SalusDatabase/Package.resolved` (SwiftPM) and
`Salus.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved` (Xcode). Every other
`Package.resolved` stays git-ignored — a graph of local paths pins nothing.

## Continuous integration

`.github/workflows/ci.yml` runs on every pull request and on pushes to `main`, in the
lint → test → build order the Android repository's `./gradlew build` uses. Every stage is a
script under `scripts/`, so CI and a laptop run the identical commands — the workflow
contains no command of its own:

| Command | What it does |
| --- | --- |
| `scripts/check-toolchain.sh` | Selects the pinned Xcode and asserts all three tool versions |
| `scripts/lint.sh` | `swiftformat --lint .` then `swiftlint --strict`, repo-wide from the repo root |
| `scripts/test-packages.sh` | `swift test` for all 24 packages under `Packages/` (accepts package names to narrow) |
| `scripts/build-app.sh` | `xcodebuild build` for the `Salus` scheme on a generic iOS Simulator destination |
| `scripts/ci.sh` | all four, in order — run this before pushing |

A clean run takes about four minutes.

Two things the scripts encode that are easy to get wrong by hand:

- **Never lint with `swiftlint --path`.** It silently disables the custom
  `no_ui_framework_in_domain` rule. Lint the repo, or pass files positionally.
- **`swift test` builds for the host, not for iOS.** So 16 of the 24 packages also declare
  `.macOS(.v14)` in their manifest purely to make the host build possible, for one of two
  reasons: they reach SwiftUI, directly (`SalusDesignSystem`) or transitively (`SalusUI` and the
  ten feature packages); or they reach GRDB, whose own manifest sets a macOS 10.15 floor that a
  manifest naming no macOS platform (SwiftPM reads that as macOS 10.13) cannot satisfy —
  `SalusDatabase` and its three dependents `SalusProfile`, `SalusAI`, `SalusReminder`. iOS 17
  stays the ship target; the iOS build of every package is what `scripts/build-app.sh` covers.
