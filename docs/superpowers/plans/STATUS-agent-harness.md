# STATUS — agent harness (iOS)

- **Phase:** executing (2026-10-14) — Task 7 done, awaiting review. Plan: `2026-10-14-agent-harness.md` (in `salus-android`).
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
