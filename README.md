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
