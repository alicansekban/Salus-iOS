# Salus iOS - Project Guide

## Language

- Everything written into the repository is **English**: code comments, doc comments, commit messages, branch names, PR descriptions and every `.md` file.
- Conversation with the owner stays **Turkish**.
- User-facing strings ship in `.xcstrings` catalogs: Turkish (default and fallback) and English.
- Code comments explain **why**, not what.

## Project Overview

Salus iOS is a **1:1 manual Swift port** of `../salus-android`: a privacy-first, offline-only health companion. Same features: appointments, medications with reminders and alarms, cycle tracking, vitals, smoking cessation, app lock; premium AI health summary, doctor report PDF, advanced trends and color themes.

- All health data stays on the device. No backend of ours, no account, no analytics.
- The only network paths are **RevenueCat** (billing) and **Firebase AI Logic + App Check** (premium AI only).
- **Android is the source of truth.** The port contract lives in the Android repo: `docs/ios-v1-plan.md`, `docs/design/design-tokens.md`, `docs/contracts/`, plus `docs/parity-ledger.md`. Domain logic is ported line for line, with Android's table tests carried over to catch drift. iOS may differ only where the contract records a decision.

## Build & Run

`Salus.xcodeproj` is **generated** from `project.yml` with `xcodegen generate`; never edit it by hand. Pinned toolchain (Xcode, XcodeGen, SwiftLint, SwiftFormat) is listed in `README.md` and checked by `scripts/check-toolchain.sh`.

- `scripts/ci.sh` - the full gate (toolchain, lint, custom lint rules, package tests, app build), ~15 min; run it before every integration, in the background.
- `scripts/test-packages.sh` - `swift test` over every package.
- `scripts/build-app.sh` - app-scheme build.
- `scripts/dev/seed-*.sh` - seed demo/health data for screenshots and QA.
- Secrets live in `App/Secrets.local.xcconfig` (owner only, never read).

## Module Architecture

A thin app target plus local Swift packages.

- `App/` - `SalusApp`, composition root (DI wiring), root navigation, tabs, lock and privacy overlays.
- `SalusModel` - pure domain models. `SalusCommon` - shared utilities.
- `SalusDatabase` - GRDB; Android's Room schemas are copied into its tests as the migration reference.
- `SalusSettings`, `SalusProfile` - preferences, keychain flags, user profile.
- `SalusDesignSystem` - tokens transcribed from Android's `design-tokens.md`, themes, palettes.
- `SalusUI` - shared SwiftUI components and charts (Swift Charts only here).
- `SalusNavigation` - routes. `SalusNotifications`, `SalusReminder` - notifications and medication alarms.
- `SalusPremium` - RevenueCat. `SalusAI` - Gemini behind a client seam. `SalusSmoking` - smoking domain.
- `SalusTesting` - shared fakes. `SalusBackup` - deferred, not linked into the app.
- `Features/*` - `Home`, `Onboarding`, `Medications`, `Appointments`, `Cycle`, `Vitals`, `Smoking`, `Trends`, `AIHealth`, `Paywall`, `Settings`.

New features follow `docs/ios-feature-template.md` (mandatory).

## Technology Stack

Swift 6 language mode with strict concurrency (never downgraded to silence an error), SwiftUI, iOS 17+, bundle id `com.alicansekban.salus`. Swift Testing for tests, SwiftLint + SwiftFormat for style.

**Dependencies - closed list of three:** GRDB, RevenueCat `purchases-ios`, `firebase-ios-sdk`. Adding a fourth is not allowed.

## Claude Setup

### Rules - `.claude/rules/`

Loaded automatically by path; subagents read them explicitly.

- `architecture.md` - settled decisions, layers, port fidelity, persisted keys, Room schema copies.
- `design-system.md` - tokens, theme, palettes, bars, toolbar, shared components.
- `copy.md` - banned health claims, disclaimer, TR/EN parity, placeholders.
- `build.md` - XcodeGen, local == CI, lint gates, test gate, pinned toolchain.
- `planning.md` - specs, plans, status, handover, rulings, manual QA, parity ledger.

### Agents - `.claude/agents/`

- `salus-architect` - drafts specs and plans under `docs/`; never writes code. Pinned to Opus.
- `salus-implementer` - implements one plan task (or one fix round) test-first and commits it.
- `salus-reviewer` - read-only review of a task's diff; returns `APPROVED` or `CHANGES_REQUIRED`.

The Jev router hook picks Sonnet or Opus for implementer/reviewer; the controller passes **no** `model` unless the owner names one.

### Skills - `.claude/skills/`

- `salus-gates` - runs the gates (`toolchain`, `lint`, `lint-rules`, `test`, `build`, or `all`) and prints one result table.
- `salus-handover` - updates the status files after every task.

### Hooks - `.claude/hooks/`

- `guard-bash.sh` - blocks force push, non-fast-forward merges, merging pulls, `git add -f`.
- `guard-files.sh` - blocks any access to `*.local.xcconfig`, edits to `project.pbxproj` and to the copied Room schemas.
- `write-scope.sh` - limits an agent's writes to given folders (used by agent frontmatter).
- Test them with `.claude/hooks/test-hooks.sh` (set `SALUS_ANDROID_DIR` to an Android checkout).

`AGENTS.md` carries the same rules for Codex/OpenCode, which do not load `.claude/`.

## Workflow

- **Read first:** `docs/superpowers/STATUS.md` (where work stands), the port contract above, then the rule file of every area the task touches. `docs/plans/` holds old milestone plans (history only); new plans go under `docs/superpowers/`.
- **Orchestration:** the controller uses `superpowers:subagent-driven-development`: implementer -> reviewer -> fixes (max 5 rounds). The controller checks diffs and test output itself, never only a report.
- **Manual QA** on a simulator or device is the owner's job. Agents write `docs/qa/m<N>-manual-qa.md` and never drive a simulator.
- **Handover:** after every task update the milestone status file (`/salus-handover`); at milestone end also `STATUS.md`. Hashes, counts and dates live there, not here.
- **Parity:** a decision touching both platforms gets a row in `../salus-android/docs/parity-ledger.md`.

## Git

- A milestone's whole scope stays on one `m<N>-*` branch; nothing reaches `main` until all tasks are done and the owner's QA has run. Parallel tasks use worktrees (`../wt-<x>`), then rebase onto the milestone branch.
- Linear history only: `git rebase main`, then `git merge --ff-only`. No merge commits.
- Commit and push only on the owner's word. An authorized plan may be committed task by task without asking again.
