# STATUS — iOS-M17 smoking cessation

- **Phase:** executing (2026-10-14) — wave 1: Tasks 1 and 8 done and reviewed; Task 4 implementing in `../wt-m17-i4`. Sync points S1–S4 open. Controller: Claude Code desktop (Opus 5.5).
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
| 1 — M17 contract sync script | `3f08e3a` | done, review APPROVED (2 deferred minors); `sync-m17-contracts-selftest: 41 passed`; `gates.sh lint` green; no Swift touched (tests 1521 → 1521) | `scripts/dev/sync-m17-contracts.sh [--check\|--status]` copies S3 vectors and S2 `5.json` from the committed `feature/m17-smoking-cessation`; open source = "not yet on branch (sync point open)", exit 0; `--check` exits 1 only on drift; `--status` prints S1–S4 (ruling R2). Red: `FAIL unknown flag exits 2: exit 127, expected 2`. Mutations: drift cmp off, S1 case-sensitive, working-tree read, open-source-fails — each failed named cases. |
| 8 — `SalusUI` additions, R2 | `a89f324` | done, review APPROVED (4 deferred minors); lint / lint-rules green; test gate **1540 tests, 0 failed, 0 skipped** (+19 on 1521) | `SalusHeatmap` (5 accent steps over `surfaceContainerHigh`, per-cell VoiceOver), `ChartUiModel.markers` + dashed accent `RuleMark` in `SalusLineChart` (`markerColor`), `overflowPermille` + `accent` on `SalusProgressRing`/`SalusProgressBar` (neutral `outlineVariant` lap). Additive. Red: `cannot find type 'ChartMarker'`. Mutations: bucket ceil→floor, marker range exclusive, overflow cap removed, zero guard dropped — each red. Open for owner QA: heatmap cells show no counts (screenshot 08 does). |

## Ledger rows to fold

Rows for `../salus-android/docs/parity-ledger.md` § M17. The Android session folds them in (runbook §4). Never commit them in the Android repo from here.

| ID | Area | iOS behaviour | Android behaviour | Why | Mirror? |
|---|---|---|---|---|---|

## Controller rulings

| Ledger line | Ruling |
|---|---|
| R1 | Ruling: implementers in `../wt-m17-i<N>` worktrees skip the status commit; the controller writes their row after integration — parallel branches would all conflict on this table — cost if wrong: rows land a little after their code. |
| R2 | Ruling: Task 1's script gets `--status` (S1–S4 reached/open) — the owner asked to check sync points with it — cost if wrong: a few script lines. |
| R3 | Ruling: Task 4 adds `Tests/SalusSmokingTests/Resources/.gitkeep` so `.copy("Resources")` resolves before S3 — cost if wrong: none. |
| R4 | Ruling: until S1, FeatureSmoking reads its accent through one internal accessor over an existing accent; Task 2 swaps that accessor — cost if wrong: a one-line follow-up in Task 2. |
| R5 | Ruling: Task 16 runs after Task 9 (wave 5), not beside it — its App callbacks need Task 9's navigation keys — cost if wrong: one wave of latency. |
| R6 | Ruling: at most one FeatureSmoking UI task per parallel wave (W1 T1∥T4∥T8 · W2 T3∥T5∥T7 · W3 T6 · W4 T9∥T19 · W5 T10∥T16∥T18 · then T13, T11, T12, T14, T15, T17 one by one; T2/T3b/T20/T22 when their sync point is reached; T21 last) — they share the catalog, strings enum and main view model — cost if wrong: longer wall clock. |
| R7 | Ruling: the controller rebases each finished side branch onto `m17-smoking` and fast-forwards; a conflicting rebase goes back to that task's implementer — cost if wrong: one extra resume. |
