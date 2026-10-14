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

- **M17 smoking cessation** — Android first: spec, Stitch review and plan live on `salus-android`'s branch
  `feature/m17-smoking-cessation` (not on its `main`). The iOS mirror gets its own plan under
  `docs/superpowers/plans/` after Android's closed testing; no iOS work has started. Alcohol is a separate milestone.
- **Agent harness** — hooks, `scripts/dev/gates.sh` and `/salus-gates`, the five area rule files, `CLAUDE.md` /
  `AGENTS.md`, the Salus agents and `/salus-handover`. Branch `chore/agent-harness` (worktree
  `Salus/wt-harness-ios`), plan `salus-android/docs/superpowers/plans/2026-10-14-agent-harness.md`, status
  `docs/superpowers/plans/STATUS-agent-harness.md`; to be fast-forwarded into `main` on the owner's word.

## Open items

- **App Store release 1.0.1:** the review verdict is not in the repository. The submission plan selects "Release manually" so both stores can go live together (`docs/appstore/store-listing.md`, "App Store Connect order", step 8); Android's Play review is the other half.
- **Next release backlog:** align the versions across the stores (iOS is `1.0.1`, Android `1.0.0`).
- **M16 manual QA:** `docs/qa/m16-manual-qa.md` has 183 rows and no recorded result; the owner walks it.
- **Encrypted backup** (`../salus-android/docs/parity-ledger.md` A2 / O-1): the format contract is still a draft, so iOS-M12 (`SalusBackup`) stays parked, no date.

## Gates baseline

`/salus-gates` test: **1521 tests** across 24 packages, 0 failed, 0 skipped (Task 7 of the harness, 2026-10-14; `all` = toolchain, lint, lint-rules, test, build, green).
