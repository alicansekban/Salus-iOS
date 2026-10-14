#!/usr/bin/env bash
# /salus-gates: the iOS gates one script at a time — the five steps of scripts/ci.sh — the Swift
# Testing counts summed from this run's own log, one table, and a non-zero exit when any row is red.
#
# usage: scripts/dev/gates.sh [toolchain|lint|lint-rules|test|build|all]… [--baseline T]
#   no step = all (toolchain, lint, lint-rules, test, build — scripts/ci.sh's order); --baseline T is
#   the test count the Δ column compares against (decimal). Several steps run in the order given,
#   each once.
#
# Exit: 0 green · 1 red, or another gates run holds the lock · 2 a bad command line or checkout,
# decided before any script runs · 130 / 143 on Ctrl-C / SIGTERM (the running step stopped first,
# then the lock released).
#
# Hidden: `gates.sh --count-swift <log>` prints `tests failed skipped` from a test-packages.sh log
# — scripts/dev/gates-selftest.sh uses it.
#
# SALUS_GATES_ROOT replaces the checkout root; it exists for gates-selftest.sh alone, whose scratch
# tree holds stand-ins for the five scripts, so no test runs swift or xcodebuild.
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"

usage() { # [reason]
  if [ -n "${1:-}" ]; then echo "gates.sh: $1" >&2; fi
  echo "usage: scripts/dev/gates.sh [toolchain|lint|lint-rules|test|build|all]… [--baseline T]" >&2
  exit 2
}

# `tests failed skipped` from the log of scripts/test-packages.sh:
#   tests   = the sum of N over the Swift Testing summary lines `✔ Test run with N tests in M suites
#             passed after …` (and `✘ … failed after … with K issues.`; `1 test` in the singular);
#             anchored on the leading mark, so a per-test line or prose that merely says the words
#             counts nothing
#   failed  = the `FAIL  <pkg>` lines — failing packages, not failing tests
#   skipped = 0: nothing in a package's output says "skipped" reliably
# A missing or empty log counts "0 0 0": the step is judged by its exit status and the zero rule.
count_swift() { # log
  local log="$1" t f
  if [ ! -f "$log" ]; then
    echo "0 0 0"
    return 0
  fi
  t="$(grep -E '^[^ ]+ Test run with [0-9]+ tests? ' "$log" 2>/dev/null |
    sed -E 's/^[^ ]+ Test run with ([0-9]+) .*/\1/' |
    awk '{ s += $1 } END { print s + 0 }')" || t=0
  f="$(grep -cE '^FAIL  ' "$log" 2>/dev/null || true)"
  echo "${t:-0} ${f:-0} 0"
}

if [ "${1:-}" = "--count-swift" ]; then
  [ $# -eq 2 ] || usage "--count-swift wants one log file"
  count_swift "$2"
  exit 0
fi

# All argument checks come before the lock, the log directory or any script.
requested=()
baseline=""
baseline_given=0
while [ $# -gt 0 ]; do
  case "$1" in
    toolchain | lint | lint-rules | test | build | all)
      requested+=("$1")
      shift
      ;;
    --baseline)
      [ $# -ge 2 ] || usage "--baseline needs the test count"
      baseline="$2"
      baseline_given=1
      shift 2
      ;;
    *) usage "unknown argument '$1'" ;;
  esac
done
if [ "${#requested[@]}" -eq 0 ]; then requested=(all); fi
baseline_re='^[0-9]+$'
if [ "$baseline_given" -eq 1 ] && ! [[ $baseline =~ $baseline_re ]]; then
  usage "--baseline wants the test count as a decimal number, e.g. 412 (got '$baseline')"
fi
# Read as base 10: bash alone takes 010 for octal eight and stops on 09 — after the test run.
baseline_count=""
if [ "$baseline_given" -eq 1 ]; then baseline_count="$((10#$baseline))"; fi

root="${SALUS_GATES_ROOT:-$(cd "$here/../.." && pwd)}"

# --- the rows of this run ----------------------------------------------------------------------

# Parallel arrays (bash 3.2 has no associative ones): row name and the script it runs.
names=()
scripts=()
add() { # name script — each step once, in the order first asked for
  local existing
  for existing in ${names[@]+"${names[@]}"}; do
    if [ "$existing" = "$1" ]; then return 0; fi
  done
  names+=("$1")
  scripts+=("$2")
}

add_step() { # step
  case "$1" in
    toolchain) add toolchain check-toolchain.sh ;;
    lint) add lint lint.sh ;;
    lint-rules) add lint-rules lint-custom-rules.sh ;;
    test) add test test-packages.sh ;;
    build) add build build-app.sh ;;
  esac
}

# `all` = scripts/ci.sh's five steps, in its order.
for s in "${requested[@]}"; do
  case "$s" in
    all)
      add_step toolchain
      add_step lint
      add_step lint-rules
      add_step test
      add_step build
      ;;
    *) add_step "$s" ;;
  esac
done

for s in ${scripts[@]+"${scripts[@]}"}; do
  [ -f "$root/scripts/$s" ] || {
    echo "gates.sh: no scripts/$s in $root" >&2
    exit 2
  }
done

# --- one run per checkout ------------------------------------------------------------------------

# Two runs in one checkout would fight over the same .build and DerivedData directories, and each
# would read the other's half-written results.
run_dir="$root/.salus-run"
mkdir -p "$run_dir"
lock="$run_dir/gates.lock"

# Alive and still a gates.sh run: a lock outlives a run killed before its EXIT trap, and macOS
# reuses pids, so a live pid that now runs something else holds nothing.
is_gates_run() { # pid
  local line
  kill -0 "$1" 2>/dev/null || return 1
  line="$(ps -o command= -p "$1" 2>/dev/null)" || return 1
  [[ $line == *gates.sh* ]]
}

# The pid in the lock. mkdir makes the lock visible a moment before its pid is written, so an empty
# pid file gets two seconds to fill; one still empty then is a run killed in between.
lock_holder() {
  local p tries=0
  while :; do
    p="$(cat "$lock/pid" 2>/dev/null || true)"
    if [ -n "$p" ] || [ "$tries" -ge 20 ]; then break; fi
    tries=$((tries + 1))
    sleep 0.1
  done
  echo "$p"
}

if ! mkdir "$lock" 2>/dev/null; then
  holder="$(lock_holder)"
  if [ -n "$holder" ] && is_gates_run "$holder"; then
    echo "gates.sh: another gates run (pid $holder) holds $lock — wait for it; never two swift/xcodebuild runs at once" >&2
    exit 1
  fi
  # A run killed before its EXIT trap leaves its lock behind; its pid is gone or runs something
  # else now, so the lock is free.
  rm -rf "$lock"
  mkdir "$lock" || {
    echo "gates.sh: cannot take $lock" >&2
    exit 1
  }
fi
echo $$ >"$lock/pid"
trap 'rm -rf "$lock"' EXIT

# Each step runs as a child this shell waits for: bash runs a trap only between commands, so a
# foreground xcodebuild would hold off a SIGTERM (a tool timeout's kill) until it ended, and a
# gates.sh killed outright leaves its swift or xcodebuild running into the next run. A background
# child also ignores the terminal's Ctrl-C, so the trap stops it.
child=""
run_child() { # log command… — sets $status
  local log="$1"
  shift
  status=0
  (cd "$root" && exec "$@") </dev/null >"$log" 2>&1 &
  child=$!
  wait "$child" || status=$?
  child=""
}
# The step's whole process tree, deepest first: the script runs swift test, which runs the test
# runner; a lone TERM to the script would leave those two running.
kill_tree() { # pid
  local c
  for c in $(pgrep -P "$1" 2>/dev/null || true); do kill_tree "$c"; done
  kill -TERM "$1" 2>/dev/null || true
}
on_signal() { # name exit-code — stop the running step, then leave (the EXIT trap frees the lock)
  trap - INT TERM
  if [ -n "$child" ]; then
    kill_tree "$child"
    wait "$child" 2>/dev/null || true
    echo "gates: SIG$1 — stopped the running step (pid $child), then released the lock" >&2
  else
    echo "gates: SIG$1 — released the lock" >&2
  fi
  exit "$2"
}
trap 'on_signal INT 130' INT
trap 'on_signal TERM 143' TERM

log_dir="$run_dir/gates/$(date +%Y%m%d-%H%M%S)"
mkdir -p "$log_dir"

# --- run -----------------------------------------------------------------------------------------

results=()
tests=()
failed=()
skipped=()
deltas=()
notes=()
reds=""

i=0
while [ "$i" -lt "${#names[@]}" ]; do
  name="${names[$i]}"
  script="${scripts[$i]}"
  log="$log_dir/$name.log"
  started=$SECONDS
  result=green
  note=""
  t="—" f="—" s="—" delta="—"

  echo "gates: $name — scripts/$script"
  run_child "$log" /bin/bash "$root/scripts/$script"
  if [ "$status" -ne 0 ]; then result=red; fi

  if [ "$name" = test ]; then
    read -r t f s <<<"$(count_swift "$log")"
    if [ "$f" -gt 0 ]; then result=red; fi
    # A test gate that ran nothing has proved nothing, whatever the script's exit status.
    if [ "$t" -eq 0 ]; then
      result=red
      note="no tests reported (no 'Test run with N tests' line in the log)"
    fi
    if [ -n "$baseline_count" ]; then
      d=$((t - baseline_count))
      if [ "$d" -ge 0 ]; then delta="+$d"; else delta="$d"; fi
    fi
  fi

  results+=("$result")
  tests+=("$t")
  failed+=("$f")
  skipped+=("$s")
  deltas+=("$delta")
  notes+=("$note")
  if [ "$result" = red ]; then reds="$reds $name"; fi
  echo "gates: $name — $result ($((SECONDS - started)) s)"
  i=$((i + 1))
done

# --- report --------------------------------------------------------------------------------------

rcell() { # width value — right-aligned; "—" is three bytes but one column
  local w="$1"
  if [ "$2" = "—" ]; then w=$((w + 2)); fi
  printf "%${w}s" "$2"
}
row() { # step result tests failed skipped delta
  printf '%-10s | %-6s | %s | %s | %s | %s\n' "$1" "$2" "$(rcell 5 "$3")" "$(rcell 6 "$4")" \
    "$(rcell 7 "$5")" "$6"
}

echo
row step result tests failed skipped "Δ"
i=0
while [ "$i" -lt "${#names[@]}" ]; do
  row "${names[$i]}" "${results[$i]}" "${tests[$i]}" "${failed[$i]}" "${skipped[$i]}" "${deltas[$i]}"
  i=$((i + 1))
done

# What a red row quotes, anchored at the start of a line: a compiler / SwiftLint diagnostic
# (`/path/File.swift:12:5: error: …`), a bare `error: …` or `::error::…` from the scripts, a
# failing package or test run (`FAIL  pkg`, `✘ …`) and xcodebuild's verdict (`** BUILD FAILED **`).
# Unanchored `error:` would also quote prose and test names that merely contain the word.
diag_re='^([^ ]+:[0-9]+(:[0-9]+)?: )?error: |^::error::|^FAIL  |^✘ |^\*\* [A-Z ]+ FAILED \*\*'
# The lint steps' reason is a violation, and SwiftFormat prints those as warnings.
lint_re="$diag_re"'|^[^ ]+:[0-9]+:[0-9]+: warning: '

# Each red row: where its whole log is, then the lines that usually say why.
i=0
while [ "$i" -lt "${#names[@]}" ]; do
  if [ "${results[$i]}" = red ]; then
    log="$log_dir/${names[$i]}.log"
    echo
    echo "red: ${names[$i]} — $log"
    if [ -n "${notes[$i]}" ]; then echo "  (${notes[$i]})"; fi
    re="$diag_re"
    case "${names[$i]}" in lint | lint-rules) re="$lint_re" ;; esac
    lines="$(grep -E "$re" "$log" 2>/dev/null | head -n 20 || true)"
    # Nothing matched (a killed tool, a script that could not start): the tail says more.
    if [ -z "$lines" ]; then lines="$(tail -n 5 "$log" 2>/dev/null || true)"; fi
    if [ -n "$lines" ]; then printf '%s\n' "$lines" | sed 's/^/  /'; fi
  fi
  i=$((i + 1))
done

echo
if [ -z "$reds" ]; then
  echo "gates: green · logs $log_dir"
  exit 0
fi
echo "gates: red —$(echo "$reds" | sed 's/ /, /g; s/^,//') · logs $log_dir"
exit 1
