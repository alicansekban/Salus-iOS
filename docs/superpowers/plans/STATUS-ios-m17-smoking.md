# STATUS — iOS-M17 smoking cessation

- **Phase:** planned (2026-10-14). Execution has not started. It starts after the agent harness merges and `m17-smoking` is rebased onto `main` (runbook §1).
- **Plan:** `docs/superpowers/plans/2026-10-14-ios-m17-smoking.md`
- **Spec:** `docs/superpowers/specs/2026-10-14-ios-m17-smoking-design.md`. It is a delta of `../salus-android/docs/superpowers/specs/2026-09-20-smoking-cessation-design.md`.
- **Runbook:** `../salus-android/docs/superpowers/plans/2026-10-14-m17-parallel-runbook.md`. The Android twin runs in parallel and owns the contracts.
- **Branch:** `m17-smoking`
- **Baseline:** 1521 tests / 24 packages (harness Task 7, 2026-10-14)
- **Ledger:** `.superpowers/sdd/2026-10-14-ios-m17-smoking/progress.md`

## Sync points consumed

| # | Needed by | Reached on the Android branch at | Synced in |
|---|---|---|---|
| S1 | Task 2 | | |
| S2 | Task 3 (or 3b) | | |
| S3 | Task 22 | | |
| S4 | Task 20 | | |

## Task log

| Task | Commit(s) | Result | Notes |
|---|---|---|---|

## Ledger rows to fold

Rows for `../salus-android/docs/parity-ledger.md` § M17. The Android session folds them in (runbook §4). Never commit them in the Android repo from here.

| ID | Area | iOS behaviour | Android behaviour | Why | Mirror? |
|---|---|---|---|---|---|

## Controller rulings

| Ledger line | Ruling |
|---|---|
