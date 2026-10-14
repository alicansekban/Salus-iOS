---
name: salus-handover
description: Write Salus iOS's four handover records in the house format — a task-log row and the Phase line of `docs/superpowers/plans/STATUS-<milestone>.md`, the checkpoint paragraph of `docs/superpowers/STATUS.md`, and a ledger line in `.superpowers/sdd/<plan>/progress.md`. Use after every task's code commit, whenever the phase changes, and before any handover, session end or environment switch.
argument-hint: <task|phase|checkpoint|ledger>
allowed-tools: Read, Grep, Edit, Bash(git log:*), Bash(git rev-parse:*), Bash(git commit:*)
---

# /salus-handover — the four handover records, no script (`.claude/rules/planning.md` → "Status and handover")

## When to use

- `task` — an implementer's code commit landed: append its row to the milestone's task log.
- `phase` — a task completed, a review or fix wave started or ended, the branch merged.
- `checkpoint` — before a handover, a session end or an environment switch; the controller writes one between tasks.
- `ledger` — the controller logs a dispatch, result, pending review, fix round, ruling, verdict or completion.

## Usage

Hashes come from git (`git rev-parse --short HEAD`, `git log --oneline <base>..HEAD`), never from memory. Grep for
the spot (status files grow), Edit it, commit that file alone: `git commit -m "docs: …" -- <path>`. Real messages
from this repository: `docs: agent-harness Task 8 — status row and rule move inventory`, `docs: agent-harness Task 7 — status row`.
New plans and status files live under `docs/superpowers/`; the iOS-M0…M14 plans in `docs/plans/` are history.

**task** — `| Task | Commit(s) | Result | Notes |` after the last row of the task log, ≤ ~700 characters, in its own
`docs:` commit after the code commit. Result: done + test counts (before + new) or the gate line; Notes: the change,
each new test's red line, the mutation checks. `docs/superpowers/plans/STATUS-agent-harness.md:15`, abridged:
```
| 7 — iOS gates runner and `/salus-gates` | `7cf4724` | done; `gates-selftest: 115 passed`; first `scripts/dev/gates.sh all`: toolchain / lint / lint-rules / test / build all green, **1521 tests, 0 failed, 0 skipped** (24 packages, test 761 s, build 144 s) | `scripts/dev/gates.sh [toolchain\|lint\|lint-rules\|test\|build\|all]… [--baseline T]` over the five `ci.sh` scripts. Red: `FAIL unknown step exits 2: exit 127, expected 2` (87 failed / 23 passed). Mutations: zero-tests rule off, live-lock check off, unanchored `error:` grep — each failed named cases. |
```

**phase** — the status file's first bullet: state (date), the tasks done and whether reviewed (implementation
complete is not review complete), the next step, the plan; at merge, the merge hash. `docs/superpowers/plans/STATUS-agent-harness.md:3`
at `18069dd`:
```
- **Phase:** executing (2026-10-14) — Tasks 7 and 8 done, awaiting review. Plan: `2026-10-14-agent-harness.md` (in `salus-android`).
```

**checkpoint** — one `docs/superpowers/STATUS.md` paragraph (under "Now"): coordinator and environment, checkout,
branch and `HEAD <hash7>`, plan / status / ledger paths, task / subtask, **models** (what the agents reported running
on), pending review or fix round, **resume:** the next action. Written from this branch's state at `18069dd`
and the shared ledger's preamble, reflowed onto one line:
```
**Checkpoint — agent harness (in progress):** coordinator Claude Code (Opus 5.5 controller), session rooted at `Salus/`, worktree `Salus/wt-harness-ios`, branch `chore/agent-harness` HEAD `18069dd`; plan `salus-android/docs/superpowers/plans/2026-10-14-agent-harness.md`, status `docs/superpowers/plans/STATUS-agent-harness.md`, ledger `salus-android/.superpowers/sdd/2026-10-14-agent-harness/progress.md` (one ledger for both repositories). Implementers and reviewers: `general-purpose`, Sonnet 5.5 and Opus 5.5 as each reported. Tasks 6–8 complete (reviews clean); **resume:** dispatch Task 9 (agents, `/salus-handover`, `STATUS.md`).
```

**ledger** — after the preamble (`# SDD ledger — plan: <path>`, then spec, branches, base, coordinator), one
`- Task <N>: …` line per event, as it happens. **Every dispatch and result line names the models its agents report
running on** (the Jev router may override the dispatched model, so the report's `Model:` line is the evidence). The
ledger is ignored and lives in the Android worktree for this plan, one for both repositories (no line numbers):
```
- Task 8: dispatched (iOS base e62544f, general-purpose opus, agent a870a3c85465efb6f; carries the planning.md 'Gates baseline' ruling)
- Task 8: implementer DONE on Sonnet 5.5 (iOS 3aa0cd9, 18069dd; move-check 404 lines: 401 verbatim, 3 headline, 0 missing; test-hooks 173; lint 0)
- Task 8: Ruling: Task 9 repoints the live human-facing "CLAUDE.md" rule citations (README.md:59, docs/ios-feature-template.md 12/56/59/235/368/434, .swiftlint.yml:289/357, scripts/lint-custom-rules.sh:181) to the rule file that now holds the rule, and fixes design-system.md:52/57's dangling "above"
- Task 8: complete (iOS commits e62544f..18069dd, review clean)
```

## Safety

- The workspace is ignored scratch; keep it during an active handover. Before a handover, environment switch or
  clean-up, copy its rulings (a "Controller rulings" table: `Ruling: <decision> — <reason> — <cost if wrong>`),
  findings, evidence and resume point to `docs/superpowers/plans/STATUS-<milestone>.md` — never into `STATUS.md`
  beyond the checkpoint, which only names the resume action. "Deferred minors" stay apart from required fixes.
- Never mark another coordinator's work complete; resume by reconciling ledger, status and git — never redispatch a
  finished task.
- Hashes, test counts and dates live in status files and git, never in `CLAUDE.md` / `AGENTS.md`; `STATUS.md` keeps
  shipped versions, the rewritten "Now", the open items and the one-line "Gates baseline" — no history.
- Commit the record's file alone, by pathspec. `salus-architect` never commits: the controller commits its edit.

## What it prints

None of its own: report the file edited, the commit hash (none for the ignored ledger) and the resume action.
