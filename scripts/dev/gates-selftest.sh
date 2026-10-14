#!/usr/bin/env bash
# Self-test for scripts/dev/gates.sh. It never runs swift or xcodebuild: SALUS_GATES_ROOT points the
# runner at a scratch tree whose five scripts/*.sh are stand-ins that log their calls and print what
# the real ones print on demand (FAKE_FAIL_ON, FAKE_TEST_OUT, FAKE_TEST_FAIL, FAKE_HANG).
#
# usage: bash scripts/dev/gates-selftest.sh   (from any directory)
set -u

here="$(cd "$(dirname "$0")" && pwd)"
GATES="$here/gates.sh"
scratch="$(mktemp -d)"
bg_pids=""
trap 'for p in $bg_pids; do pkill -P "$p" 2>/dev/null; kill "$p" 2>/dev/null; done; rm -rf "$scratch"' EXIT

passed=0
failed=0
n=0
OUT=""
CODE=0
ROOT=""
CALLS=""

fail() { echo "FAIL $1"; failed=$((failed + 1)); }
pass() { passed=$((passed + 1)); }

# A fresh stand-in tree: the five scripts the runner calls, each logging "<name>" to calls.log.
#   FAKE_FAIL_ON=<script name>  that script prints diagnostics and exits 1
#   FAKE_TEST_OUT=<text>        what test-packages.sh prints instead of its two-package green run
#   FAKE_TEST_FAIL=1            test-packages.sh reports one failing package and exits 1
#   FAKE_TEST_EXIT=<code>       test-packages.sh exits with that code after its green output
#   FAKE_HANG=<script name>     that script records its pids and sleeps (for the signal case)
newroot() {
    n=$((n + 1))
    ROOT="$scratch/t$n"
    CALLS="$ROOT/calls.log"
    mkdir -p "$ROOT/scripts"
    : >"$CALLS"
    local s
    for s in check-toolchain lint lint-custom-rules test-packages build-app; do
        cat >"$ROOT/scripts/$s.sh" <<STUB
#!/bin/bash
echo "$s" >>"\$CALLS"
if [ "\${FAKE_HANG-}" = "$s" ]; then
    echo \$\$ >"\$HANG_DIR/script.pid"
    sleep 120 &
    echo \$! >"\$HANG_DIR/sleeper.pid"
    wait
fi
if [ "\${FAKE_FAIL_ON-}" = "$s" ]; then
    echo "note: 'error: inside prose' is not a diagnostic, and neither is a stray hexe: here"
    echo "/p/Sources/F.swift:12:5: error: cannot find 'x' in scope"
    echo "error: found no Package.swift"
    echo "** BUILD FAILED **"
    exit 1
fi
STUB
    done
    cat >>"$ROOT/scripts/test-packages.sh" <<'STUB'
if [ -n "${FAKE_TEST_OUT+x}" ]; then
    printf '%s\n' "$FAKE_TEST_OUT"
elif [ -n "${FAKE_TEST_FAIL-}" ]; then
    echo "✔ Test run with 12 tests in 3 suites passed after 0.5 seconds."
    echo "PASS  SalusA"
    echo "✘ Test run with 5 tests in 1 suite failed after 0.1 seconds with 2 issues."
    echo "FAIL  SalusB"
    echo "==> summary: 1/2 packages passed"
    exit 1
else
    echo "✔ Test run with 12 tests in 3 suites passed after 0.5 seconds."
    echo "PASS  SalusA"
    echo "✔ Test run with 5 tests in 2 suites passed after 0.1 seconds."
    echo "PASS  SalusB"
    echo "==> summary: 2/2 packages passed"
fi
exit "${FAKE_TEST_EXIT-0}"
STUB
}

# g <args…>: runs gates.sh on $ROOT; sets OUT (stdout+stderr) and CODE
g() {
    if [ ! -f "$GATES" ]; then OUT="gates.sh not found"; CODE=127; return 1; fi
    OUT="$(SALUS_GATES_ROOT="$ROOT" CALLS="$CALLS" HANG_DIR="$ROOT" /bin/bash "$GATES" "$@" 2>&1)"
    CODE=$?
}

calls() { cat "$CALLS" 2>/dev/null; }
squeezed() { printf '%s\n' "$OUT" | tr -s ' '; }

expect_exit() { # name code
    if [ "$CODE" -ne "$2" ]; then
        fail "$1: exit $CODE, expected $2"
    else
        pass
    fi
}
expect_row() { # name "squeezed row"
    if ! squeezed | grep -qxF -- "$2"; then
        fail "$1: no row '$2' in: $(squeezed | tr '\n' '~')"
    else
        pass
    fi
}
expect_line() { # name exact-line
    if ! printf '%s\n' "$OUT" | grep -qxF -- "$2"; then
        fail "$1: no line '$2' in: $(printf '%s' "$OUT" | tr '\n' '~')"
    else
        pass
    fi
}
expect_no_line() { # name exact-line
    if printf '%s\n' "$OUT" | grep -qxF -- "$2"; then
        fail "$1: unexpected line '$2'"
    else
        pass
    fi
}
expect_has() { # name substring
    case "$OUT" in
    *"$2"*) pass ;;
    *) fail "$1: output lacks '$2': $(printf '%s' "$OUT" | tr '\n' '~')" ;;
    esac
}
expect_calls() { # name expected
    local got
    got="$(calls)"
    if [ "$got" != "$2" ]; then
        fail "$1: calls were: $(printf '%s' "$got" | tr '\n' '~'), expected: $(printf '%s' "$2" | tr '\n' '~')"
    else
        pass
    fi
}
expect_no_calls() { expect_calls "$1" ""; }
expect_gone() { # name path
    if [ -e "$2" ]; then fail "$1: $2 still exists"; else pass; fi
}
expect_out_eq() { # name expected
    if [ "$OUT" = "$2" ]; then pass; else fail "$1: expected '$2', got '$OUT'"; fi
}

TOOLCHAIN_CALL="check-toolchain"
LINT_CALL="lint"
RULES_CALL="lint-custom-rules"
TEST_CALL="test-packages"
BUILD_CALL="build-app"

# --- command line: exit 2 before the lock, the log directory or any script ---------------------------

newroot
g nope
expect_exit "unknown step exits 2" 2
expect_has "unknown step prints usage" "usage: scripts/dev/gates.sh"
expect_no_calls "unknown step starts nothing"
expect_gone "unknown step creates no run dir" "$ROOT/.salus-run"

for bad in "--baseline x" "--baseline" "--baseline 1/2/3" "--baseline -4" "--baseline 12x"; do
    newroot
    # shellcheck disable=SC2086
    g test $bad
    expect_exit "'$bad' exits 2" 2
    expect_has "'$bad' prints usage" "usage:"
    expect_no_calls "'$bad' starts nothing"
    expect_gone "'$bad' creates no run dir" "$ROOT/.salus-run"
done

# an empty baseline is a bad one, not an absent one
newroot
g test --baseline ""
expect_exit "--baseline '' exits 2" 2
expect_has "--baseline '' prints usage" "usage:"
expect_no_calls "--baseline '' starts nothing"
expect_gone "--baseline '' creates no run dir" "$ROOT/.salus-run"

newroot
g test --frobnicate
expect_exit "unknown option exits 2" 2
expect_no_calls "unknown option starts nothing"

# a checkout without the scripts is a bad checkout: exit 2, nothing started
newroot
rm "$ROOT/scripts/build-app.sh"
g build
expect_exit "a missing script exits 2" 2
expect_gone "a missing script creates no run dir" "$ROOT/.salus-run"

# --- --count-swift ----------------------------------------------------------------------------------

newroot
fx="$ROOT/swift.log"
cat >"$fx" <<'LOG'
==> swift test across 3 package(s)

::group::[ 1/3] SalusA
◇ Test run started.
✔ Test run with 12 tests in 3 suites passed after 0.5 seconds.
::endgroup::
PASS  SalusA

::group::[ 2/3] SalusX
✔ Test run with 12 tests in 3 suites passed after 0.5 seconds.
::endgroup::
FAIL  SalusX

==> summary: 1/2 packages passed
==> failing packages:
  - SalusX
LOG
g --count-swift "$fx"
expect_exit "--count-swift exits 0" 0
expect_out_eq "--count-swift sums the Test run lines, counts FAIL lines ('24 1 0')" "24 1 0"

printf '✔ Test run with 1 test in 1 suite passed after 0.0 seconds.\n✘ Test run with 3 tests in 1 suite failed after 0.1 seconds with 2 issues.\n' >"$fx"
g --count-swift "$fx"
expect_out_eq "--count-swift reads the singular 'test' and a failed run ('4 0 0')" "4 0 0"

# only the summary line counts: neither a per-test line, nor 'Test run started', nor prose
printf '◇ Test run started.\n✔ Test "a test run with 9 tests" passed after 0.0 seconds.\nsome prose: Test run with 7 tests\nFAIL SalusX\n  FAIL  SalusY\n' >"$fx"
g --count-swift "$fx"
expect_out_eq "--count-swift counts nothing but summary and FAIL lines ('0 0 0')" "0 0 0"

g --count-swift "$ROOT/missing.log"
expect_out_eq "--count-swift over a missing log prints '0 0 0'" "0 0 0"
: >"$fx"
g --count-swift "$fx"
expect_out_eq "--count-swift over an empty log prints '0 0 0'" "0 0 0"
expect_no_calls "--count-swift starts nothing"

# --- the lock ---------------------------------------------------------------------------------------

# A live process whose command line names gates.sh stands in for another gates run.
newroot
bash -c 'sleep 120; : "$0"' gates.sh >/dev/null 2>&1 &
holder=$!
disown "$holder"
bg_pids="$bg_pids $holder"
mkdir -p "$ROOT/.salus-run/gates.lock"
echo "$holder" >"$ROOT/.salus-run/gates.lock/pid"
g test
expect_exit "held lock exits 1" 1
expect_has "held lock names the holder" "pid $holder"
expect_no_calls "held lock starts no script"
if [ ! -d "$ROOT/.salus-run/gates.lock" ] || [ "$(cat "$ROOT/.salus-run/gates.lock/pid")" != "$holder" ]; then
    fail "held lock is left untouched"
else
    pass
fi
expect_gone "held lock creates no log dir" "$ROOT/.salus-run/gates"
g toolchain
expect_exit "held lock refuses toolchain too" 1
expect_no_calls "held lock runs no toolchain check"
pkill -P "$holder" 2>/dev/null; kill "$holder" 2>/dev/null

# a lock whose pid is dead is stale
newroot
mkdir -p "$ROOT/.salus-run/gates.lock"
sleep 0 &
dead=$!
wait "$dead"
echo "$dead" >"$ROOT/.salus-run/gates.lock/pid"
g lint
expect_exit "stale lock (dead pid) is reclaimed" 0
expect_calls "stale lock run reaches the script" "$LINT_CALL"
expect_gone "the lock is released after a run" "$ROOT/.salus-run/gates.lock"

# a live pid that is not a gates run holds nothing (pids are reused)
newroot
sleep 120 >/dev/null 2>&1 &
other=$!
disown "$other"
bg_pids="$bg_pids $other"
mkdir -p "$ROOT/.salus-run/gates.lock"
echo "$other" >"$ROOT/.salus-run/gates.lock/pid"
g lint
expect_exit "lock held by an unrelated live pid is reclaimed" 0
expect_gone "that lock is released too" "$ROOT/.salus-run/gates.lock"
kill "$other" 2>/dev/null

# a lock with no pid file (run killed between mkdir and echo) is stale once the grace has passed
newroot
mkdir -p "$ROOT/.salus-run/gates.lock"
g lint
expect_exit "lock without a pid is reclaimed" 0

# a signal stops the running step, releases the lock and exits 143
newroot
FAKE_HANG=test-packages SALUS_GATES_ROOT="$ROOT" CALLS="$CALLS" HANG_DIR="$ROOT" \
    /bin/bash "$GATES" test >"$ROOT/hang.out" 2>&1 &
gpid=$!
bg_pids="$bg_pids $gpid"
tries=0
while [ ! -s "$ROOT/sleeper.pid" ] && [ "$tries" -lt 100 ]; do
    sleep 0.1
    tries=$((tries + 1))
done
sleeper="$(cat "$ROOT/sleeper.pid" 2>/dev/null || true)"
scriptpid="$(cat "$ROOT/script.pid" 2>/dev/null || true)"
if [ -z "$sleeper" ]; then
    fail "signal case: the stand-in step never started"
else
    kill -TERM "$gpid"
    tries=0
    while kill -0 "$gpid" 2>/dev/null && [ "$tries" -lt 50 ]; do
        sleep 0.1
        tries=$((tries + 1))
    done
    if kill -0 "$gpid" 2>/dev/null; then
        fail "SIGTERM ends gates.sh within five seconds"
        kill -KILL "$gpid" 2>/dev/null
    else
        pass
    fi
    wait "$gpid" 2>/dev/null
    CODE=$?
    expect_exit "SIGTERM exits 143" 143
    if kill -0 "$sleeper" 2>/dev/null; then fail "SIGTERM leaves the step's process running"; else pass; fi
    if [ -n "$scriptpid" ] && kill -0 "$scriptpid" 2>/dev/null; then fail "SIGTERM leaves the step running"; else pass; fi
    expect_gone "SIGTERM releases the lock" "$ROOT/.salus-run/gates.lock"
    if grep -q 'SIGTERM' "$ROOT/hang.out"; then pass; else fail "SIGTERM says it stopped the step"; fi
fi
kill "$sleeper" 2>/dev/null

# --- test -------------------------------------------------------------------------------------------

newroot
g test --baseline 10
expect_exit "test green exits 0" 0
expect_calls "test runs scripts/test-packages.sh" "$TEST_CALL"
expect_row "test header" "step | result | tests | failed | skipped | Δ"
expect_row "test row (12 + 5 tests, Δ vs 10)" "test | green | 17 | 0 | 0 | +7"
if printf '%s\n' "$OUT" | grep -q '^gates: green · logs '"$ROOT"'/.salus-run/gates/[0-9]\{8\}-[0-9]\{6\}$'; then
    pass
else
    fail "test summary line: $(printf '%s' "$OUT" | tail -n 1)"
fi
if ls "$ROOT"/.salus-run/gates/*/test.log >/dev/null 2>&1; then pass; else fail "test.log written under .salus-run/gates/<ts>/"; fi
expect_gone "test releases the lock" "$ROOT/.salus-run/gates.lock"

newroot
g test --baseline 010
expect_row "negative Δ against a decimal baseline (010 = ten... 17 - 10)" "test | green | 17 | 0 | 0 | +7"

newroot
g test --baseline 30
expect_row "negative Δ is signed" "test | green | 17 | 0 | 0 | -13"

newroot
g test --baseline 17
expect_row "Δ zero is +0" "test | green | 17 | 0 | 0 | +0"

newroot
g test
expect_row "no baseline, no Δ" "test | green | 17 | 0 | 0 | —"

# zero tests: red, never green, even though the script exited 0
newroot
FAKE_TEST_OUT="==> summary: 0/0 packages passed" g test
expect_exit "test with zero tests exits 1" 1
expect_row "test with zero tests is red" "test | red | 0 | 0 | 0 | —"
expect_has "zero-test row says so" "no tests reported"
expect_has "zero-test summary is red" "gates: red — test"

# a failing package: red, counted, with the log path and the FAIL line
newroot
FAKE_TEST_FAIL=1 g test --baseline 17
expect_exit "a failing package exits 1" 1
expect_row "failed = FAIL package lines" "test | red | 17 | 1 | 0 | +0"
if printf '%s\n' "$OUT" | grep -q '^red: test — '"$ROOT"'/.salus-run/gates/.*/test\.log$'; then pass; else fail "red row names the test log"; fi
expect_line "red row quotes the FAIL line" "  FAIL  SalusB"
expect_line "red row quotes the failed run line" "  ✘ Test run with 5 tests in 1 suite failed after 0.1 seconds with 2 issues."

# a non-zero exit is red even when the log shows nothing failed
newroot
FAKE_TEST_EXIT=3 g test
expect_exit "a non-zero test script exits 1" 1
expect_row "non-zero test script is red" "test | red | 17 | 0 | 0 | —"

# --- the other steps --------------------------------------------------------------------------------

newroot
g toolchain
expect_exit "toolchain green" 0
expect_calls "toolchain runs check-toolchain.sh" "$TOOLCHAIN_CALL"
expect_row "toolchain row" "toolchain | green | — | — | — | —"

newroot
g lint
expect_calls "lint runs lint.sh" "$LINT_CALL"
expect_row "lint row" "lint | green | — | — | — | —"

newroot
g lint-rules
expect_calls "lint-rules runs lint-custom-rules.sh" "$RULES_CALL"
expect_row "lint-rules row" "lint-rules | green | — | — | — | —"

newroot
g build
expect_exit "build green" 0
expect_calls "build runs build-app.sh" "$BUILD_CALL"
expect_row "build row" "build | green | — | — | — | —"

# a red row quotes the diagnostics, anchored: not prose that merely contains 'error:' or 'e: '
newroot
FAKE_FAIL_ON=build-app g build
expect_exit "red build exits 1" 1
expect_row "red build row" "build | red | — | — | — | —"
if printf '%s\n' "$OUT" | grep -q '^red: build — '"$ROOT"'/.salus-run/gates/.*/build\.log$'; then pass; else fail "red row names the build log"; fi
expect_line "red row quotes a compiler error" "  /p/Sources/F.swift:12:5: error: cannot find 'x' in scope"
expect_line "red row quotes a bare error:" "  error: found no Package.swift"
expect_line "red row quotes the xcodebuild verdict" "  ** BUILD FAILED **"
expect_no_line "red row does not quote prose containing error:" "  note: 'error: inside prose' is not a diagnostic, and neither is a stray hexe: here"

# nothing matches: the tail of the log
newroot
cat >"$ROOT/scripts/lint.sh" <<'STUB'
#!/bin/bash
echo "lint" >>"$CALLS"
echo "something odd happened"
exit 1
STUB
g lint
expect_exit "red lint exits 1" 1
expect_line "a red row with no diagnostics shows the log tail" "  something odd happened"

# --- all --------------------------------------------------------------------------------------------

ALL_CALLS="$TOOLCHAIN_CALL
$LINT_CALL
$RULES_CALL
$TEST_CALL
$BUILD_CALL"

newroot
g all
expect_exit "all green" 0
expect_calls "all = toolchain, lint, lint-rules, test, build in order" "$ALL_CALLS"
expect_row "all toolchain row" "toolchain | green | — | — | — | —"
expect_row "all lint row" "lint | green | — | — | — | —"
expect_row "all lint-rules row" "lint-rules | green | — | — | — | —"
expect_row "all test row" "test | green | 17 | 0 | 0 | —"
expect_row "all build row" "build | green | — | — | — | —"

newroot
g
expect_calls "no step runs all" "$ALL_CALLS"

newroot
FAKE_FAIL_ON=lint g all
expect_exit "all with a red lint exits 1" 1
expect_calls "all keeps going after a red step" "$ALL_CALLS"
expect_row "all still has the toolchain row" "toolchain | green | — | — | — | —"
expect_row "all's lint row is red" "lint | red | — | — | — | —"
expect_row "all still has the test row" "test | green | 17 | 0 | 0 | —"
expect_has "all's summary names the red step" "gates: red — lint"

newroot
g lint test lint
expect_calls "several steps run in the given order, once each" "$LINT_CALL
$TEST_CALL"

newroot
g build all
expect_calls "all after a step does not repeat it" "$BUILD_CALL
$TOOLCHAIN_CALL
$LINT_CALL
$RULES_CALL
$TEST_CALL"

# --- result -----------------------------------------------------------------------------------------

if [ "$failed" -ne 0 ]; then
    echo "gates-selftest: $failed failed, $passed passed"
    exit 1
fi
echo "gates-selftest: $passed passed"
