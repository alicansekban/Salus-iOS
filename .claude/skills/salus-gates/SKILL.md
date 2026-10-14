---
name: salus-gates
description: Run Salus iOS's CI gates one script at a time — toolchain check, SwiftFormat + SwiftLint, the custom-rule fixtures, `swift test` over every package with the Swift Testing counts, and the app-scheme build — and print one table with the Δ against a baseline. Use before reporting a task done, before a review verdict and at a milestone's close-out.
argument-hint: "[toolchain|lint|lint-rules|test|build|all]… [--baseline T]"
allowed-tools: Bash(scripts/dev/gates.sh:*), Bash(pgrep:*)
---

# /salus-gates — a thin wrapper over `scripts/dev/gates.sh` (run it from the checkout)

## When to use

- Before reporting a task done: the brief's steps (else `test`, plus `lint` / `lint-rules` / `build`
  for what the task touched) and its baseline.
- Before a review verdict: the same steps, compared with the implementer's counts.
- At close-out: `all` — the same five steps, in the same order, as `scripts/ci.sh`.

## Usage

```bash
scripts/dev/gates.sh test
scripts/dev/gates.sh all --baseline 3400
```

| Step | What runs |
|---|---|
| `toolchain` | `scripts/check-toolchain.sh` — Xcode / SwiftLint / SwiftFormat against the README pins |
| `lint` | `scripts/lint.sh` — `swiftformat --lint .`, then `swiftlint --strict` |
| `lint-rules` | `scripts/lint-custom-rules.sh` — planted fixtures proving the custom rules still fire |
| `test` | `scripts/test-packages.sh` — `swift test` in every package under `Packages/` |
| `build` | `scripts/build-app.sh` — `xcodebuild` of the `Salus` scheme for the generic iOS Simulator |
| `all` (no step) | `toolchain`, `lint`, `lint-rules`, `test`, `build` |

- Several steps run in the order given, each once; a red step does not stop the run.
- `test` counts come from that run's own log: **tests** = the sum of N over the Swift Testing
  summary lines `Test run with N tests in M suites …`; **failed** = the `FAIL  <pkg>` lines —
  failing *packages*, not failing tests; **skipped** is always 0 (nothing in the output says
  "skipped" reliably).
- `--baseline T` = the test count (decimal); Δ = tests − T, on the `test` row only.
- Logs: `.salus-run/gates/<YYYYmmdd-HHMMSS>/<step>.log` (git-ignored, per checkout).

## Safety

- **Never two swift / xcodebuild runs at once**, nor another checkout's gates in parallel. First
  `pgrep -fl 'xcodebuild|swift-test|swift-build'`: one line per run. A second gates run in the same
  checkout is refused (exit 1, nothing started): the lock is `.salus-run/gates.lock`, a stale one
  (dead pid) is reclaimed.
- `all` takes several minutes (25 packages, then an `xcodebuild`) and can outlast a 10-minute tool
  call: run it (and `test`, `build`) in the background and wait for the exit.
- `App/Secrets.local.xcconfig` is optional (`#include?`) and absent in worktrees: `build` works
  without it. Never create it or copy one in.
- A red gate is fixed or reported with its log path, never skipped or re-run until it passes.

## What it prints

A progress line per step, then one table:

```
step       | result | tests | failed | skipped | Δ
toolchain  | green  |     — |      — |       — | —
lint       | green  |     — |      — |       — | —
lint-rules | green  |     — |      — |       — | —
test       | green  |  3400 |      0 |       0 | +0
build      | green  |     — |      — |       — | —

gates: green · logs /Users/…/Salus/wt-x/.salus-run/gates/20261014-120000
```

`test` is red on a non-zero script exit, a `FAIL  <pkg>` line or zero tests. Each red row adds its
log path and its first 20 lines that *start* with a diagnostic — `file.swift:12:5: error: …`,
`error: …`, `::error::…`, `FAIL  <pkg>`, `✘ …`, `** BUILD FAILED **` (the lint steps also quote
`file.swift:12:5: warning: …`); with none, the log's last 5 lines. Exit 0 green, 1 red or lock held,
2 a bad command line or checkout (before any script runs), 130 / 143 on Ctrl-C / SIGTERM (the
running step's whole process tree stopped first, then the lock released).
