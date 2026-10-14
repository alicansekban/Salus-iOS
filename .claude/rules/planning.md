---
paths:
  - "**/docs/**"
---
# Planning rules — specs, plans, status, handover, manual QA (`docs/**`)

Global rules are in `CLAUDE.md`. Everything in the repository is English; conversation with the
owner is Turkish. The Android twin is `../salus-android` and the reference platform: the port
contract, the design tokens, the backup format and the parity ledger live there.

## Process

- **One milestone = one branch** (`mX-*`), **one or a few conventional commits per task, in
  English; squashing is not required.** The earlier wording said "one commit per task", and no
  milestone has ever matched it: iOS-M1's tasks were multi-commit, and iOS-M2's ran 1-4 commits each
  (Task 1 took four — three independent library changes plus a script — and every review fix round
  added one). The reason to keep them separate is that a fix round's commit is the reviewable unit;
  squashing it into the feature commit hides what review changed. What is binding is that **each
  commit is a conventional commit that builds**, and that a task's commits are contiguous — not
  their count. Rewritten 2026-08-23 (iOS-M2 Task 8) to match the history instead of the other way
  round.
- **Linear history only.** Rebase onto `main`, fast-forward merge (`git merge --ff-only`). Never
  `--no-ff`, never a merge commit.
- Review before merge; `scripts/ci.sh` green is the entry ticket, not the finish line.
- **A milestone's manual QA sheet lives in `docs/qa/m<N>-manual-qa.md`.** That is the current
  home; the sheets from iOS-M3 to iOS-M14 still sit in `scripts/` and stay where they are, but no
  new one is written there — a checklist a human reads is documentation, and `scripts/` is for
  things that run. The sheet is written by the milestone's sweep task, hands the owner one row per
  screen plus a "known risks" section for everything the automated gate cannot see (live theme
  repaint, Dynamic Type at xxxLarge, sheet heights, VoiceOver order), and is what the owner walks
  before the merge. `scripts/ci.sh` green is the entry ticket to that walk. — *review.*

## Specs

- `docs/superpowers/specs/YYYY-MM-DD-<topic>-design.md`, opening with `Status:` (approved in brainstorm on <date>), the platforms it covers, and "Builds on". The spec wins over any design export. An iOS milestone starts from its Android twin's spec and says only what differs.
- Product choices are settled one question at a time, numbered Q1, Q2… with lettered A/B/C options and a recommendation, asked about the **end state** the owner will see; out-of-scope work needs the owner's approval. Decisions are a `| # | Decision | Why |` table (D1…) that plans cite and never re-argue.
- Finish the spec and the plan before execution; execution starts in a fresh session on the owner's word.

## Plans

- New plans go to `docs/superpowers/plans/YYYY-MM-DD-<topic>.md`, **compact**: at most ~500 lines of contracts, exact paths and signatures, behaviour lists and concrete test cases — no full code bodies. Point at the spec for tables and wording; split an oversized milestone. `docs/plans/` (iOS-M0…M14) is history and stays where it is.
- Header in this order: the sub-skill blockquote, Goal, Architecture, Tech stack, Spec, Branch / checkout, Status file. Then "Global constraints" (the gates, their commands and baseline counts) and "Rulings the planner made (do not re-open)".
- Tasks are `### Task N:` with Files, Interfaces (consumes / produces), and `- [ ]` steps: failing test with its expected red line, run, implement, run, commit. A ported type carries its Android table tests. Checkboxes follow the verified state.
- A big milestone's whole scope stays on **one branch** (`m<N>-*`); nothing merges to `main` until every task is done and the owner's QA has run — not even the token layer. Independent tasks may run in parallel worktrees (`git worktree add ../wt-<x>`) on side branches and are then rebased onto the milestone branch.
- The plan ends with the controller's close-out: whole-branch review, one fix wave, `/salus-gates all` (or `scripts/ci.sh`), QA hand-off, `git rebase main` + `git merge --ff-only` (linear history, never `--no-ff`), `STATUS.md` — push only on the owner's word.
- A behaviour change Android must mirror, or an iOS-side decision that touches Android, records a row in `../salus-android/docs/parity-ledger.md` (an Android-repo commit) at the time the plan records it.

## Design work

- UI milestones follow the Android twin's flow: spec → Stitch prompts → the **owner's** export → a design review → the plan. Those artifacts live in `../salus-android/docs/design/` (`m<N>-…-stitch-prompts.md`, `m<N>-stitch/`, `m<N>-stitch-review.md`); an iOS plan cites the review's rulings and never plans before the export.
- Screenshots give layout, hierarchy and component choice; copy, numbers and colours come from the spec and `../salus-android/docs/design/design-tokens.md`. Quote Turkish UI copy exactly as the app shows it.

## Status and handover

- `docs/superpowers/STATUS.md` stays one short page: shipped versions, a rewritten "Now", open items moved between the lists. History, rulings and test counts never go there, except the one-line "Gates baseline"; hashes, counts and dates never go in `CLAUDE.md` / `AGENTS.md`.
- A milestone's `docs/superpowers/plans/STATUS-<milestone>.md` opens with Phase, plan, spec, branch, baseline and the ledger path, then the task log `Task | Commit(s) | Result | Notes`: each implementer appends its row (≤ ~700 characters) in its own `docs:` commit. Use `/salus-handover`. Open a large status file only at the section `STATUS.md` points at.
- Update the milestone status after every task and before any handover: task, exact phase, commit range, verification and result, open findings, rulings, next action. Implementation complete is not review complete.
- A handover checkpoint names the coordinator and environment, branch and HEAD, plan and ledger, task, models, fix round and the resume action; never mark another coordinator's work complete. Resume by reconciling ledger, status and git — never redispatch a finished task.
- The ledger is `.superpowers/sdd/<plan>/progress.md` (first line names the plan), with briefs, reports and review packages in the same workspace. It is ignored scratch: copy rulings, findings and the resume point into the tracked status before switching environments or cleaning up.
- Shared project decisions belong in repository documents, never only in agent memory or the conversation.
- Rulings are `Ruling: <decision> — <reason> — <cost if wrong>`, in a "Controller rulings" table; "Deferred minors" stay apart from required fixes.
- Manual-pass feedback becomes a small fix plan and a fix wave on the same branch.

## Manual QA — the owner's job

- The sheet's shape: what the automated gates already cover, the device and set-up in the owner's terms, then numbered steps each with an **Expected:** result. The owner walks it on a simulator or device.
- Agents never drive a simulator or device and never claim a visual or on-device result; they write the sheet, run the gates and say exactly what was verified — compiling is not a visual check.
- Quote Turkish UI copy verbatim; list known differences from `main` and from Android.
