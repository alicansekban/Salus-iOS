# STATUS — agent harness (iOS)

- **Phase:** executing (2026-10-14) — Task 6 done, awaiting review. Plan: `2026-10-14-agent-harness.md` (in `salus-android`).
- **Plan:** `salus-android`'s `docs/superpowers/plans/2026-10-14-agent-harness.md`
- **Spec:** `salus-android`'s `docs/superpowers/specs/2026-10-14-agent-harness-design.md`
- **Branch:** `chore/agent-harness` (worktree `Salus/wt-harness-ios`)
- **Baseline:** none yet — Task 7 records the first.
- **Ledger:** `salus-android`'s `.superpowers/sdd/2026-10-14-agent-harness/progress.md` (one ledger for both repositories)

## Task log

| Task | Commit(s) | Result | Notes |
|---|---|---|---|
| 6 — iOS hooks and settings | `5ca3201` | done; `test-hooks: 173 passed` (with `SALUS_ANDROID_DIR` pointing at the Android worktree; the same 173 without it, the three identity checks skipping) | `lib.sh`, `guard-bash.sh`, `write-scope.sh` and `settings.json` copied byte-identical from Android `ba0492d`; iOS's own `guard-files.sh` (any `*.local.xcconfig` blocked for every tool; `Salus.xcodeproj/project.pbxproj` and `Packages/SalusDatabase/Tests/**/RoomSchemas/*.json` blocked for writes). Red: `FAIL guard-bash blocks: git push --force origin x: exit 127, expected 2` (hooks missing), then `FAIL guard-files blocks Read: …/App/Secrets.local.xcconfig: exit 127, expected 2` with the shared three in place. Mutations: `.local.xcconfig` matched case-sensitively → `FAIL guard-files blocks Read: App/SECRETS.LOCAL.XCCONFIG`; an Android copy with one extra byte → `FAIL guard-bash.sh: identical to Android's`. |
