# Salus iOS — status

One short page (`.claude/rules/planning.md` → "Status and handover"): shipped versions, the rewritten
"Now", the open items. History, rulings and per-task logs live in `plans/STATUS-<milestone>.md` and in
git. Written 2026-10-14; update it at the end of a milestone and, between tasks, through
`/salus-handover checkpoint`.

## Done

| What | Evidence |
|---|---|
| **1.0.1 (build 5)** submitted for App Store review on 2026-09-13, with the tr + en-US listing, eight 6.9" screenshots and the TestFlight sandbox pass; no review verdict is recorded in the repository | `docs/appstore/store-listing.md` (checklist, "Submitted for review — 1.0.1 (5)"); `project.yml` (`MARKETING_VERSION` / `CURRENT_PROJECT_VERSION`) |
| Everything before it: the port of the whole v1 feature set (iOS-M0 skeleton to iOS-M8 settings and onboarding), premium (RevenueCat), the AI health features, trends, reminder readiness, in-app review, post-launch motion, premium theme accents and the M16 UI overhaul | `git log main`; `docs/plans/` (iOS-M0…M14, history); `docs/superpowers/plans/` (one file per later milestone); `docs/qa/m16-manual-qa.md` |

## Now

- **iOS-M17 smoking cessation** — **done and fast-forwarded into `main`** at `6a749f9` on the owner's word (2026-10-15), **not pushed**; the owner's manual QA still runs (fixes land on a new branch off `main`). Built in parallel with Android on contracts owned by the Android repo. Version 1.1.0 (6).
  - status `docs/superpowers/plans/STATUS-ios-m17-smoking.md` (task log, rulings, ledger rows to fold);
  - manual QA `docs/qa/m17-manual-qa.md` — walk it together with Android's sheet (runbook §4.4);
  - delta spec `docs/superpowers/specs/2026-10-14-ios-m17-smoking-design.md`; plan `docs/superpowers/plans/2026-10-14-ios-m17-smoking.md`.
  - **Checkpoint:** coordinator Claude Code (Opus 5.5 controller), checkout `salus-ios`, branch `m17-smoking` HEAD `8679d00`; implementers Sonnet 5.5, reviewers Opus 5.5 / Sonnet 5.5 as each reported. Tasks 1–23 complete and reviewed, whole-branch review and final fix wave approved, `gates.sh all` green. **Resume:** the owner's QA; push only on the owner's word. Android folds parity rows D-M17-i-7 and i-8.
- **Agent harness** — done and fast-forwarded into `main` (plan `salus-android/docs/superpowers/plans/2026-10-14-agent-harness.md`, status `docs/superpowers/plans/STATUS-agent-harness.md`).

## Open items

- **App Store release 1.0.1:** the review verdict is not in the repository. The submission plan selects "Release manually" so both stores can go live together (`docs/appstore/store-listing.md`, "App Store Connect order", step 8); Android's Play review is the other half.
- **Next release backlog:** align the versions across the stores (iOS `m17-smoking` is `1.1.0 (6)`, `main` `1.0.1`; Android `1.0.0`). The 1.1.0 What's New text in `docs/appstore/store-listing.md` is the owner's to write.
- **Follow-up after M17:** one shared deadline-based `waitUntil` test helper in `SalusTesting` (the eleven feature copies drifted in M17).
- **Encrypted backup** (`../salus-android/docs/parity-ledger.md` A2 / O-1): the format contract is still a draft, so iOS-M12 (`SalusBackup`) stays parked, no date.

## Gates baseline

`/salus-gates` test: **2284 tests** across 26 packages, 0 failed, 0 skipped (iOS-M17 close-out on `m17-smoking`, 2026-10-15; `all` = toolchain, lint, lint-rules, test, build, green). 
