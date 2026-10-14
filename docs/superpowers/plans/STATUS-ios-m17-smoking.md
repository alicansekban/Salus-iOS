# STATUS — iOS-M17 smoking cessation

- **Phase:** executing (2026-10-14) — Tasks 1, 4, 8, 20 done and reviewed; Task 2 in review; Task 3 implementing; Tasks 5, 7 next. All sync points S1–S4 reached. Controller: Claude Code desktop (Opus 5.5).
- **Plan:** `docs/superpowers/plans/2026-10-14-ios-m17-smoking.md`
- **Spec:** `docs/superpowers/specs/2026-10-14-ios-m17-smoking-design.md`. It is a delta of `../salus-android/docs/superpowers/specs/2026-09-20-smoking-cessation-design.md`.
- **Runbook:** `../salus-android/docs/superpowers/plans/2026-10-14-m17-parallel-runbook.md`. The Android twin runs in parallel and owns the contracts.
- **Branch:** `m17-smoking`
- **Baseline:** 1521 tests / 24 packages (harness Task 7, 2026-10-14)
- **Ledger:** `.superpowers/sdd/2026-10-14-ios-m17-smoking/progress.md`

## Sync points consumed

| # | Needed by | Reached on the Android branch at | Synced in |
|---|---|---|---|
| S1 | Task 2 | `61f1d68` (checked 2026-10-14) | Task 2 `8ccb1e6` |
| S2 | Task 3 | `2045f43` | Task 3 `b85f574` |
| S3 | Task 22 | `59e88d0` (stats vectors; schedule vectors with Android T5) |  |
| S4 | Task 20 | `49c42d9` | Task 20 `49005ba` (wraps the script; nothing copied) |

## Task log

| Task | Commit(s) | Result | Notes |
|---|---|---|---|
| 1 — M17 contract sync script | `3f08e3a` | done, review APPROVED (2 deferred minors); `sync-m17-contracts-selftest: 41 passed`; `gates.sh lint` green; no Swift touched (tests 1521 → 1521) | `scripts/dev/sync-m17-contracts.sh [--check\|--status]` copies S3 vectors and S2 `5.json` from the committed `feature/m17-smoking-cessation`; open source = "not yet on branch (sync point open)", exit 0; `--check` exits 1 only on drift; `--status` prints S1–S4 (ruling R2). Red: `FAIL unknown flag exits 2: exit 127, expected 2`. Mutations: drift cmp off, S1 case-sensitive, working-tree read, open-source-fails — each failed named cases. |
| 8 — `SalusUI` additions, R2 | `a89f324` | done, review APPROVED (4 deferred minors); lint / lint-rules green; test gate **1540 tests, 0 failed, 0 skipped** (+19 on 1521) | `SalusHeatmap` (5 accent steps over `surfaceContainerHigh`, per-cell VoiceOver), `ChartUiModel.markers` + dashed accent `RuleMark` in `SalusLineChart` (`markerColor`), `overflowPermille` + `accent` on `SalusProgressRing`/`SalusProgressBar` (neutral `outlineVariant` lap). Additive. Red: `cannot find type 'ChartMarker'`. Mutations: bucket ceil→floor, marker range exclusive, overflow cap removed, zero guard dropped — each red. Open for owner QA: heatmap cells show no counts (screenshot 08 does). |
| 20 — Dev tooling: smoking shift wrapper | `49005ba` | done, review APPROVED (2 deferred minors); `smoking-shift-selftest: 27 passed`; lint + lint-rules green (no Swift) | `scripts/dev/smoking-shift.sh [--db <path>] <days>` wraps Android's `smoking_shift.py` (S4) on the simulator `salus.db`, `.bak` kept; `--db` for scratch dry runs. Note `docs/testing/smoking-testing.md`. `seed-store-demo.sh` unchanged. Red: `FAIL shift 7 exits 0: exit 127`. Mutations: days>0 check, backup `cp`, constant days — each red. Dry run: Android seeder + shift 30 on a v5 scratch DB moved attempts exactly 30 d. |
| 4 — SalusSmoking package, models, `SmokingStatsCalculator` (contract §2, §3, §8) | `826baf7`, `184ce0f` (fix round 1) | done, review APPROVED after fix round 1; lint / lint-rules green; SalusSmoking 53 + SalusCommon 90 green; full gates before the fix: **1570 tests (1521 + 49), 0 failed**, 25 packages, build green | New package + `epochDay(of:in:)`/`startOfDayMs(epochDay:in:)` in `SalusClock` (P2). One test per §3 rule. Red: `cannot find 'SmokingStatsCalculator' in scope`. 30 mutations red. Fix round 1: QUIT goal floored per attempt (§8.2), unlinked events owned by containment (§8.1, Kotlin `EventsByAttempt`), target ≤ 0 → 0 permille, package count 25 in ci.yml/skill/BannedHealthClaims, README macOS count. |
| 2 — amber smoking feature accent (S1) | `8ccb1e6` | done, review APPROVED (3 deferred minors); lint / lint-rules green; tests 1540 → **1542** (+2) on its base | `SalusExtendedColors.smoking` for classic/Ocean/Sunset/Forest × light/dark, 32 hexes from Android `61f1d68` / design-tokens §3.1/§3.2/§4.6; pins 241 tokens / 6 sets (rule text updated); hue test ≥ 25° from error (twin of Android's). Red: `(featureAccents.count → 5) == 6`. Mutations: hex +1, red accent, dark hex in light slot, entry removed — each red. Hex-initializer suite moved verbatim (500-line limit); one local `function_parameter_count` exemption. |
| 3 — GRDB migration `v5` + `SmokingDao` (contract §1, §8.6) | `b85f574` | done, review APPROVED; lint / lint-rules green; tests 1540 → **1558** (+18) on its base; SalusDatabase 114 green | Five records + `SmokingDao` (plain struct like `CycleDao`; SQL and order match Android `2045f43`; 5 conflated streams, 11 writes, `resetAll`, `write(_:)` over a `Transaction` with the 5 reads). `5.json` via `sync-m17-contracts.sh`, byte-identical; `RoomSchemaParityTests` v1…v5 in the same commit (no Task 3b). Red: `Fatal error: undefined migration: "v5"`. 10 mutations red. `update*` throws `recordNotFound` where Room no-ops (MedicationDao precedent). |
| 7 — `SmokingInsightsCalculator` (contract §5, §8.7) | `89b0445` | done, review APPROVED (3 deferred minors); lint / lint-rules green; SalusSmoking 53 → **98** (+45) | `insights(_:nowMs:zone:windowDays:)` and `aiStats(_:fromEpochDay:toEpochDay:zone:) -> SmokingAiStats?` (mode, daysTracked, slipCount, topTriggers, busiestBand, reductionPercent — no currency; field set pinned). `HourBand` `h08_10`…`h22_08` (scoped `identifier_name` disable). Matches Android Kotlin line for line. Red: `cannot find type 'SmokingInsights' in scope`. 10 mutations red. |
| 6 — repository + use cases (contract §6, §8.10) | `a364d27` | done, review APPROVED (5 deferred minors); lint / lint-rules / build green; SalusSmoking 53 → **138** (+85) on its base | `SmokingRepository` (`observeInput`/`observeSnapshot`/`snapshotNow`), 15 `Sendable` use cases, one GRDB write transaction per use case (double tap decided inside the tx), listeners notified after commit; `SmokingCoreModule` built once in `makeInfrastructure` with an empty `SmokingChangeListeners` registry (Task 17 adds the reminder listener). Observer reads via `SmokingDao.write` (DatabaseQueue: no extra contention). Red: compile error in `SmokingTestEnv.swift`. 12 mutations red. |
| 5 — `MilestoneCatalog` + `MilestoneScheduler` (contract §4 amended, §8.8, §8.9) | `bd006b6` | done, review APPROVED (1 deferred minor → ledger row D-M17-i-1); lint / lint-rules green; SalusSmoking 53 → **89** (+36) on its base | Latest-instant firing, first-48 h `:early` split keys, quiet hours by wall-clock minute, slip shift, limit (capped at 1000), evening, yearly past 15 y, TRY vs EUR steps. Reviewer mirrored the algorithm: 14/14 golden `scheduleCases` (0fd295f) pass. `groupByOwningAttempt` internal + shared `unitCost(on:ascendingPrices:)`. Red: `cannot find type 'PlannedNotification' in scope`. 12 mutations red. |
| 18 — Trends smoking section + quit markers (screen 08) | `2dfa9ce`, `c63f6f1` | done, review APPROVED (3 deferred minors); lint / lint-rules / build green; FeatureTrends 114 → **144** (+30), SalusUI 160 → **165** (+5) | Section hidden without a plan, last under the existing Trends lock, 4 cards + 7-day empty state; "Bıraktın" markers inside the span only. `MultiSeriesChartUiModel.markers` added in SalusUI (own commit, mirrors Android da134b1). 60 keys (58 Android + 2 `_one` twins); heatmap count word "kayıt"/"entries" per §8.12 (Android still "kriz" — row D-M17-i-2). 6 mutations red. |

## Ledger rows to fold

Rows for `../salus-android/docs/parity-ledger.md` § M17. The Android session folds them in (runbook §4). Never commit them in the Android repo from here.

| ID | Area | iOS behaviour | Android behaviour | Why | Mirror? |
|---|---|---|---|---|---|
| D-M17-i-2 | Trends heatmap copy | `trends_smoking_heatmap_count` = "kayıt" / "entries" ("entry" for 1), per contract §8.12 | branch still ships "kriz" / "craving" | §8.12 owner decision; joint close-out string parity | Android updates the string |
| D-M17-i-1 | Smoking scheduler | `MilestoneScheduler.plan` caps `limit` at `maximumLimit = 1000`; `limit ≤ 0` plans nothing | `take(limit)` over a Long horizon; no cap (`Int.MAX` would build ~7.8×10¹¹ yearly candidates) | iOS Int64 day horizon would wrap; no caller asks for > 64 | Optional: Android adopts the cap, or §8.9 records the reading |

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
| R8–R11 | Ruling: R4 placeholder accent moot (S1 reached before Task 9) · Tasks 2, 3 (with parity, no 3b) and 20 run beside Task 4's review since S1/S2/S4 are reached · Task 4 fix round 1 carries its three minors · contract §8 (added by Android mid-execution) is binding, and every brief now says to read the contract at branch head — cost if wrong: none. |
