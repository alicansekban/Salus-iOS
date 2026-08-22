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

The versions above are pinned: `.github/workflows/ci.yml` asserts Xcode, SwiftLint and
SwiftFormat against this table and fails the run if the GitHub runner image drifts away
from it. Bump the table and the workflow's `Toolchain` step in the same commit.

## Continuous integration

`.github/workflows/ci.yml` runs on every pull request and on pushes to `main`, in the
lint → test → build order the Android repository's `./gradlew build` uses. Each stage is a
script under `scripts/`, so CI and a laptop run the identical commands:

| Command | What it does |
| --- | --- |
| `scripts/lint.sh` | `swiftformat --lint .` then `swiftlint --strict`, repo-wide from the repo root |
| `scripts/test-packages.sh` | `swift test` for all 24 packages under `Packages/` (accepts package names to narrow) |
| `scripts/build-app.sh` | `xcodebuild build` for the `Salus` scheme on a generic iOS Simulator destination |
| `scripts/ci.sh` | all three, in order — run this before pushing |

A clean run takes about four minutes.

Two things the scripts encode that are easy to get wrong by hand:

- **Never lint with `swiftlint --path`.** It silently disables the custom
  `no_ui_framework_in_domain` rule. Lint the repo, or pass files positionally.
- **`swift test` builds for the host, not for iOS.** So an iOS-only package that reaches
  SwiftUI — directly (`SalusDesignSystem`) or transitively (`SalusUI` and the ten feature
  packages) — also declares `.macOS(.v14)` in its manifest purely to make the host build
  possible. iOS 17 stays the ship target; the iOS build of every package is what
  `scripts/build-app.sh` covers.
