# STATUS — agent harness (iOS)

- **Phase:** final fix wave done (2026-10-14) — Tasks 6–9 complete and reviewed, the whole-branch reviews' fix package (F1–F20) applied in both repositories; awaiting the controller's scoped re-review and the owner's merge word. Plan: `2026-10-14-agent-harness.md` (in `salus-android`).
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
| Final fix wave (F1–F20, both repos) | `8725b1d`, `dcdf0fd`, records | done; `test-hooks: 231 passed`, shared files `cmp`-identical to Android, `gates-selftest: 115 passed`, lint clean, `gates.sh all` green (1521 tests, +0) | Shared hooks and `settings.json` copied from Android `a09366a`; iOS `guard-files.sh` judges Grep like Read and fails closed. Agents, `/salus-handover`, `AGENTS.md`, the Room schema path (`architecture.md`, amended line), `STATUS.md` per the package; report in the shared ledger workspace, `final-fix-report.md`. |

## Controller rulings

Every `Ruling:` line of the ledger (`salus-android's .superpowers/sdd/2026-10-14-agent-harness/progress.md`) that concerns this repository, verbatim.

| Ledger line | Ruling |
|---|---|
| 28 | R1: Ruling: Android and iOS chains run concurrently, one implementer per repository at a time; T6 starts after T1 completes, T7 after T3, T8 after T4, T9 after T5 — separate worktrees in separate repositories share no files; the skill's "no parallel implementers" guards one checkout — cost if wrong: a merge-free but duplicated fix if an Android review changes a copied file after iOS copied it (T6 re-copies at close-out). |
| 29 | R2: Ruling: iOS byte-identity check (ruling 2) compares against `$SALUS_ANDROID_DIR` when set, else `../salus-android`; for this branch run it with `SALUS_ANDROID_DIR=…/wt-harness-android` — the main checkout lacks the hooks until merge — cost if wrong: identity check skipped silently on other machines (it already skips when the dir is absent). |
| 30 | R3: Ruling: move-check.sh and frontmatter-check.sh live in this android workspace and are passed to iOS implementers by absolute path — they are throwaway verification tools — cost if wrong: none. |
| 31 | R4: Ruling: move-check gets an explicit `--amended <file>` list (old line → new line) for owner-approved wording changes; Q1-A's `PaywallScreen` sentence is its only entry — cost if wrong: none. |
| 32 | R5: Ruling: the harness's own agents do not exist yet, so implementers/reviewers dispatch as `general-purpose` with an explicit model (Opus for T1/T6 hooks and final review, Sonnet otherwise); the Jev router routes built-in agents itself and may override — cost if wrong: a task lands on a weaker tier; reviews still gate it. |
| 73 | Task 5: Ruling: the gates baseline stays in STATUS.md — spec §10 requires "counts recorded as the first baseline in each STATUS.md"; Tork's rule bars counts only from CLAUDE.md/AGENTS.md — cost if wrong: one line to move. |
| 74 | Task 5: Ruling: a spec/rule conflict stops the agents with NEEDS_CONTEXT (no Tork-style "spec wins" clause) — Salus has no such owner decision; asking is the safe default — cost if wrong: an extra controller round-trip on a conflict. |
| 75 | Task 5: Ruling: planning.md's STATUS.md bullet gets the exception "except the one-line 'Gates baseline'" — fixed in the final fix wave on Android; iOS Task 8 writes the amended wording from the start — cost if wrong: one clause. |
| 86 | Task 8: Ruling: Task 9 repoints the live human-facing "CLAUDE.md" rule citations (README.md:59, docs/ios-feature-template.md 12/56/59/235/368/434, .swiftlint.yml:289/357, scripts/lint-custom-rules.sh:181) to the rule file that now holds the rule, and fixes design-system.md:52/57's dangling "above" (→ "in `architecture.md`") — Swift comments and history docs stay (CLAUDE.md still routes) — cost if wrong: a few comment/message lines. |
| 97 | Final fix wave: Ruling: one fixer for both repos (shared hook files must move together; Android first, cp to iOS) with the consolidated package final-fix-package.md (F1–F20) — cost if wrong: a longer single dispatch. Dispatched (base android 60de14b / iOS 9d80516, opus, agent a4e885ca654cca566) |
| 98 | Final fix wave: Ruling: guard-files gains Grep in its matcher (F4) and repo_rel mismatch after same_repo blocks (F1, fail closed) — both reviewers found secret reads slipping through — cost if wrong: a Grep on a secret file path refused. |

## Deferred minors

Every `minor (deferred)` ledger line for this repository that the final fix wave does not fix, verbatim (a note follows where the wave fixed part of a line).

- ledger 44: Task 1: minor (deferred): write-scope.sh comment example `docs/../app/x.kt` is Android-flavoured (still byte-identical; cosmetic)
- ledger 50: Task 6: minor (deferred): identity check skips (and counts as passed) when SALUS_ANDROID_DIR is set but wrong — fail when the variable is set explicitly and the dir is missing
- ledger 51: Task 6: minor (deferred): settings.json identity not asserted by iOS test-hooks (one cmp -s line)
- ledger 81: Task 7: minor (deferred): selftest case label for `--baseline 010` garbled ("negative Δ…" but asserts +7)
- ledger 82: Task 7: minor (deferred): skipped always 0 / failed counts packages (documented; Swift Testing `◇ … skipped` lines could feed a count later); lint red-row regex verified only against stubs
- ledger 87: Task 8: minor (deferred): Task 8 status row ~900 chars
- ledger 91: Task 9: minor (deferred, owner question): iOS STATUS.md open item "M16 manual QA 183 rows, no recorded result" probably stale (owner QA rounds 1–4 happened)
- ledger 92: Task 9: minor (deferred): remaining "CLAUDE.md" citations — scripts/m10-manual-qa.md:157, docs/research m8 inventories, ~60 Swift comments (CLAUDE.md still routes)


## Rule move inventory

Spec D9: rules move, they are not rewritten. `move-check.sh` (ledger workspace) accounts for every non-blank, non-heading line of the old `CLAUDE.md` (429 lines, snapshot of `a1e2535`): 401 occur verbatim in exactly one new file, 3 are mapped to a headline that exists there (the "Milestone plans live in `docs/plans/`" line, now part of `CLAUDE.md` "Read first" with the `docs/superpowers/` rule; the two-line English-documentation bullet, now `CLAUDE.md` "Language rule (project-wide)"), none was amended at the move. Three lines were amended afterwards, each by a ruling (move-check `--amended`, ledger `task-8/amended.tsv`: 404 lines · 398 verbatim · 3 headline · 3 amended · 0 missing): `design-system.md`'s two dangling "(the rule above)" / "(above)" now say "in `architecture.md`" (Task 8 ruling, carried out by Task 9's `135b177`), and `architecture.md`'s Room schema copy path, `salus-android/app/schemas/…`, which never existed, now reads `salus-android/core/database/schemas/com.alicansekban.salus.core.database.SalusDatabase/…` (final fix wave F7, an owner-approved factual correction). Each section moved whole; the enforcement notes travel with their rule.

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
| Port fidelity rules | The Room schema JSONs are copied, not authored, and re-synced on ev… | architecture.md (verbatim; one line amended — F7 schema path) |
| Design system rules | `salus-android/docs/design/design-tokens.md` is the only source of… | design-system.md (verbatim) |
| Design system rules | `SalusDesignSystem` is tokens only, no views | design-system.md (verbatim) |
| Design system rules | The resolved theme travels in the environment, never as a parameter | design-system.md (verbatim) |
| Design system rules | Color literals live in `private enum` palettes | design-system.md (verbatim) |
| Design system rules | No inline hex outside the palette files, and no raw point size outs… | design-system.md (verbatim) |
| Design system rules | The shell owns the bars; a feature paints neither | design-system.md (verbatim; two lines amended — "above" → "in `architecture.md`") |
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
