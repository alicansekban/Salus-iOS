# STATUS — agent harness (iOS)

- **Phase:** executing (2026-10-14) — Tasks 7 and 8 done, awaiting review. Plan: `2026-10-14-agent-harness.md` (in `salus-android`).
- **Plan:** `salus-android`'s `docs/superpowers/plans/2026-10-14-agent-harness.md`
- **Spec:** `salus-android`'s `docs/superpowers/specs/2026-10-14-agent-harness-design.md`
- **Branch:** `chore/agent-harness` (worktree `Salus/wt-harness-ios`)
- **Baseline:** 1521 tests across 24 packages, 0 failed (first `gates.sh all`, Task 7, 2026-10-14).
- **Ledger:** `salus-android`'s `.superpowers/sdd/2026-10-14-agent-harness/progress.md` (one ledger for both repositories)

## Task log

| Task | Commit(s) | Result | Notes |
|---|---|---|---|
| 6 — iOS hooks and settings | `5ca3201` | done; `test-hooks: 173 passed` (with `SALUS_ANDROID_DIR` pointing at the Android worktree; the same 173 without it, the three identity checks skipping) | `lib.sh`, `guard-bash.sh`, `write-scope.sh` and `settings.json` copied byte-identical from Android `ba0492d`; iOS's own `guard-files.sh` (any `*.local.xcconfig` blocked for every tool; `Salus.xcodeproj/project.pbxproj` and `Packages/SalusDatabase/Tests/**/RoomSchemas/*.json` blocked for writes). Red: `FAIL guard-bash blocks: git push --force origin x: exit 127, expected 2` (hooks missing), then `FAIL guard-files blocks Read: …/App/Secrets.local.xcconfig: exit 127, expected 2` with the shared three in place. Mutations: `.local.xcconfig` matched case-sensitively → `FAIL guard-files blocks Read: App/SECRETS.LOCAL.XCCONFIG`; an Android copy with one extra byte → `FAIL guard-bash.sh: identical to Android's`. |
| 7 — iOS gates runner and `/salus-gates` | `7cf4724` | done; `gates-selftest: 115 passed`; first `scripts/dev/gates.sh all`: toolchain / lint / lint-rules / test / build all green, **1521 tests, 0 failed, 0 skipped** (24 packages, test 761 s, build 144 s) | `scripts/dev/gates.sh [toolchain\|lint\|lint-rules\|test\|build\|all]… [--baseline T]` over the five `ci.sh` scripts; hidden `--count-swift <log>`; Android Task 3's table, exits, lock and signals, with its two minors fixed (anchored red-row grep, `--baseline ""` exits 2). Red: `FAIL unknown step exits 2: exit 127, expected 2` (87 failed / 23 passed). Mutations: zero-tests rule off, live-lock check off, unanchored `error:` grep, empty baseline accepted, signal handler not killing the step tree, FAIL count off — each failed named cases. |
| 8 — iOS rules, `CLAUDE.md`, `AGENTS.md` | `3aa0cd9`, status | done; `move-check: GREEN` (404 lines: 401 verbatim, 3 headline, 0 amended), `test-hooks: 173 passed`, `scripts/lint.sh` clean | `architecture.md` (Settled decisions + Layer rules + Port fidelity, minus the language bullet), `design-system.md`, `copy.md`, `build.md` = the old sections whole; `planning.md` = "Process" verbatim + Android Task 4's adapted to iOS paths (`docs/superpowers/`, `docs/qa/`, parity ledger and design work in `../salus-android`); `CLAUDE.md` 30 lines (was 429; port-contract pointers, rules table, settled-decision headlines, checks, models, checkout); `AGENTS.md` 18 lines, no model table. Red: `move-check: 404 lines · 0 verbatim … 404 missing` (RED). Mutations: a changed word in `architecture.md`, the language headline removed, two rule files concatenated (45 DUP), `planning.md` omitted — each RED. |
| 9 — iOS agents, `/salus-handover`, `STATUS.md` | `498b44b`, `135b177`, status | done; `frontmatter-check: GREEN`, `test-hooks: 173 passed`, `scripts/lint.sh` and `lint-custom-rules.sh` green | `salus-implementer` / `-reviewer` / `-architect` (Android Task 5's shape, iOS gates, `xcodegen`, `RoomSchemas` `cp`, catalog-parity pins; the architect gains a spec-vs-rule conflict clause), `/salus-handover` with this branch's rows, first iOS `STATUS.md` (1.0.1 build 5 submitted; M17 mirror after Android closed testing; baseline 1521). `135b177` repoints the "CLAUDE.md" rule citations. Red: `FAIL …/salus-implementer.md: file missing` (4 failed). |

## Rule move inventory

Spec D9: rules move, they are not rewritten. `move-check.sh` (ledger workspace) accounts for every non-blank, non-heading line of the old `CLAUDE.md` (429 lines, snapshot of `a1e2535`): 401 occur verbatim in exactly one new file, 3 are mapped to a headline that exists there (the "Milestone plans live in `docs/plans/`" line, now part of `CLAUDE.md` "Read first" with the `docs/superpowers/` rule; the two-line English-documentation bullet, now `CLAUDE.md` "Language rule (project-wide)"), none was amended. Each section moved whole; the enforcement notes travel with their rule.

| Old section | Bullet heading | New home |
|---|---|---|
| - | Port contract (source of truth…) | CLAUDE.md (verbatim) |
| - | A 1:1 manual Swift port… (enforcement-point preamble) | CLAUDE.md (verbatim) |
| - | Milestone plans live in `docs/plans/`. Toolchain and CI usage | CLAUDE.md (Read first — headline) |
| Settled decisions (do not relitigate) | The dependency allowlist is closed and is exactly three | architecture.md (verbatim) + CLAUDE.md headline |
| Settled decisions (do not relitigate) | Offline-first, local-only: no backend of ours, no analytics, no ad-… | architecture.md (verbatim) + CLAUDE.md headline |
| Settled decisions (do not relitigate) | Deployment target iOS 17; bundle identifier `com.alicansekban… | architecture.md (verbatim) + CLAUDE.md headline |
| Settled decisions (do not relitigate) | Swift 6 language mode everywhere, strict concurrency from day one | architecture.md (verbatim) + CLAUDE.md headline |
| Settled decisions (do not relitigate) | All project documentation, code comments and commit messages are … | CLAUDE.md (Language rule, headline) |
| Settled decisions (do not relitigate) | UI framework | architecture.md (verbatim) + CLAUDE.md headline |
| Settled decisions (do not relitigate) | The tab bar is the shell's, and it shows only on a tab's root | architecture.md (verbatim) |
| Settled decisions (do not relitigate) | `docs/ios-feature-template.md` is the reference for every new feature | architecture.md (verbatim) |
| Layer rules | No UI framework in the domain layer | architecture.md (verbatim) |
| Layer rules | Records and DAOs live in `SalusDatabase`; mappers live with the dom… | architecture.md (verbatim) |
| Layer rules | `LocalDate` is `SalusModel`'s, and `epochDay` is the wire | architecture.md (verbatim) |
| Layer rules | The composition root owns the singletons; there is no container | architecture.md (verbatim) |
| Layer rules | Features never depend on each other | architecture.md (verbatim) |
| Layer rules | Packages mirror the Gradle modules 1:1 | architecture.md (verbatim) |
| Layer rules | `.macOS(.v14)` in a manifest is a test-host concession, not a target | architecture.md (verbatim) |
| Port fidelity rules | Domain logic is hand-ported 1:1 from Kotlin | architecture.md (verbatim) |
| Port fidelity rules | Behaviour differences only where spec §6 records a decision | architecture.md (verbatim) |
| Port fidelity rules | Every persisted key and value string is Android-verbatim | architecture.md (verbatim) |
| Port fidelity rules | The Keychain holds exactly one thing: `app_lock_enabled` | architecture.md (verbatim) |
| Port fidelity rules | The Room schema JSONs are copied, not authored, and re-synced on ev… | architecture.md (verbatim) |
| Design system rules | `salus-android/docs/design/design-tokens.md` is the only source of… | design-system.md (verbatim) |
| Design system rules | `SalusDesignSystem` is tokens only, no views | design-system.md (verbatim) |
| Design system rules | The resolved theme travels in the environment, never as a parameter | design-system.md (verbatim) |
| Design system rules | Color literals live in `private enum` palettes | design-system.md (verbatim) |
| Design system rules | No inline hex outside the palette files, and no raw point size outs… | design-system.md (verbatim) |
| Design system rules | The shell owns the bars; a feature paints neither | design-system.md (verbatim) |
| Design system rules | A pushed screen writes `.navigationTitle` + inline mode + `Toolba… | design-system.md (verbatim) |
| Design system rules | The shared components are the vocabulary, and it is closed | design-system.md (verbatim) |
| Design system rules | `SalusSegmentedTabs` is the content-tab control; `Picker(.segmented… | design-system.md (verbatim) |
| Design system rules | `SalusStepperField` owns no range, and the caller contract that rep… | design-system.md (verbatim) |
| Copy and localisation rules | Banned health-claims vocabulary applies to all user-facing copy | copy.md (verbatim) |
| Copy and localisation rules | The AI/PDF disclaimer is verbatim and mandatory | copy.md (verbatim) |
| Copy and localisation rules | TR + EN string parity | copy.md (verbatim) |
| Copy and localisation rules | Overlines are stored upper-case in the resource, never folded at ru… | copy.md (verbatim) |
| Project file and build rules | `Salus.xcodeproj` is generated by XcodeGen from `project.yml` and c… | build.md (verbatim) |
| Project file and build rules | Local == CI | build.md (verbatim) |
| Project file and build rules | Lint gate | build.md (verbatim) |
| Project file and build rules | Custom-rule gate | build.md (verbatim) |
| Project file and build rules | Test gate | build.md (verbatim) |
| Project file and build rules | The toolchain is pinned | build.md (verbatim) |
| Project file and build rules | No force unwrapping / force cast / force try in production code; te… | build.md (verbatim) |
| Process | One milestone = one branch | planning.md (verbatim) |
| Process | Linear history only | planning.md (verbatim) |
| Process | Review before merge; `scripts/ci.sh` green is the entry ticket, not… | planning.md (verbatim) |
| Process | A milestone's manual QA sheet lives in `docs/qa/m<N>-manual-qa.md` | planning.md (verbatim) |
