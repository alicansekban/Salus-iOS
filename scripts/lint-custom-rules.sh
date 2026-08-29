#!/bin/bash
#
# Proves the `.swiftlint.yml` custom rules actually fire — the negative fixture
# test the rules themselves cannot be.
#
# Why this script exists. A SwiftLint custom rule is a regex plus an `included:`
# scope, and BOTH halves fail silently: a regex that matches nothing and a scope
# that matches no file produce the same output as a clean tree. The measurements
# in .swiftlint.yml were originally taken by hand (plant an import, run the
# linter, read the count, delete the import); doing that by hand is exactly the
# kind of step that gets skipped the one time a rule is edited.
#
# So: for every custom rule, this plants a file that MUST trip it inside the
# rule's scope, and an identical file OUTSIDE that scope which must NOT trip it.
# The second half is the one that catches an `included:` regex gone too wide.
# A rule scoped by `excluded:` rather than by directory has no "outside" to
# plant in, so it gets `check_carve_out` instead: the same planted positive, and
# a negative half made of the sanctioned files already in the tree.
#
#   scripts/lint-custom-rules.sh
#
# Exits 0 when every rule fired where it should and stayed quiet where it should.
# The fixtures are removed on every exit path, interrupts included.
#
# NOTE: this runs `swiftlint` REPO-WIDE from the repo root, never `--path` — see
# the warning in .swiftlint.yml and scripts/lint.sh.
#
# It IS part of the pipeline: step 3 of 5 in scripts/ci.sh and the "Custom lint
# rules" step of .github/workflows/ci.yml, between lint and test. An earlier
# revision of this header argued the opposite — that a fifth script was not worth
# the edit to both files plus the README — which had the effect of leaving the
# only proof that the custom rules still fire in a script nothing ran. Adding a
# custom rule therefore also means adding a `check` block below, in the same
# commit; run this directly while iterating on a rule's regex.

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT" || exit 1

# Every fixture planted, so the trap can remove them whatever happens.
FIXTURES=""

cleanup() {
    for fixture in $FIXTURES; do
        rm -f "$fixture"
    done
}
trap cleanup EXIT INT TERM

failures=0

# plant <path> <body>
#
# `body` is written verbatim under a delete-on-sight header, and may be more than
# one line — `check_carve_out` plants a multi-line body so that lines which MUST
# trip a rule and lines which MUST NOT sit in the same file, seen by the same run.
plant() {
    mkdir -p "$(dirname "$1")"
    printf '// Fixture planted by scripts/lint-custom-rules.sh. Delete on sight.\n%s\n' "$2" > "$1"
    FIXTURES="$FIXTURES $1"
}

# check <rule-id> <in-scope-file> <out-of-scope-file> <import-line>
check() {
    rule="$1"
    inside="$2"
    outside="$3"
    line="$4"

    plant "$inside" "$line"
    plant "$outside" "$line"

    output="$(swiftlint --quiet 2>/dev/null)"
    hits_inside="$(printf '%s\n' "$output" | grep -c "$inside.*($rule)")"
    hits_outside="$(printf '%s\n' "$output" | grep -c "$outside.*($rule)")"

    if [ "$hits_inside" -eq 1 ]; then
        echo "PASS  $rule fired on $inside"
    else
        echo "FAIL  $rule did NOT fire on $inside (expected 1 hit, got $hits_inside)"
        failures=$((failures + 1))
    fi

    if [ "$hits_outside" -eq 0 ]; then
        echo "PASS  $rule stayed quiet on $outside"
    else
        echo "FAIL  $rule fired outside its scope, on $outside ($hits_outside hits)"
        failures=$((failures + 1))
    fi

    rm -f "$inside" "$outside"
}

# check_carve_out <rule-id> <in-scope-file> <expected-hits> <body> <sanctioned-file>...
#
# The shape a carve-out rule needs, and the reason `check` above does not fit
# it: `no_calendar_outside_clock` scopes itself with `included:` (the whole
# tree) MINUS an `excluded:` list of named files, so there is no "outside the
# scope" directory to plant a negative fixture in. The negative half is instead
# the carve-out files themselves — they are already in the tree, they already
# build a `Calendar`, and they must stay quiet in the SAME repo-wide run that
# the planted fixture trips. That makes them a free negative fixture nothing has
# to plant, and it measures the half worth measuring: whether SwiftLint honours
# `excluded:` on a CUSTOM rule (it does, on 0.65.0 — this is what proves it).
#
# `expected-hits` is asserted EXACTLY, not as a floor, which is what lets `body`
# carry decoy lines: a line that must not trip the rule is proved quiet by the
# total not moving. `check` above cannot express that — it asserts 1 and 0 on two
# separate files.
check_carve_out() {
    rule="$1"
    inside="$2"
    expected="$3"
    body="$4"
    shift 4

    plant "$inside" "$body"

    output="$(swiftlint --quiet 2>/dev/null)"
    hits_inside="$(printf '%s\n' "$output" | grep -c "$inside.*($rule)")"

    if [ "$hits_inside" -eq "$expected" ]; then
        echo "PASS  $rule fired exactly $expected time(s) on $inside"
    else
        echo "FAIL  $rule fired $hits_inside time(s) on $inside (expected $expected)"
        failures=$((failures + 1))
    fi

    for sanctioned in "$@"; do
        hits="$(printf '%s\n' "$output" | grep -c "$sanctioned.*($rule)")"
        if [ "$hits" -eq 0 ]; then
            echo "PASS  $rule stayed quiet on the carve-out $sanctioned"
        else
            echo "FAIL  $rule fired on the sanctioned $sanctioned ($hits hits)"
            failures=$((failures + 1))
        fi
    done

    rm -f "$inside"
}

echo "==> planting fixtures and linting the repo"
echo

# Guard 1: the domain layer must never see a UI framework. The scoped-import
# spelling is planted rather than the plain one, because that is the form a
# regex without the import-kind grammar sails straight past.
check "no_ui_framework_in_domain" \
    "Packages/SalusModel/Sources/SalusModel/LintFixtureDoNotCommit.swift" \
    "Packages/SalusUI/Sources/SalusUI/LintFixtureDoNotCommit.swift" \
    "import struct SwiftUI.Color"

# Guard 2: features must not import Charts. `@preconcurrency` is planted for the
# same reason — it is the attribute-prefixed form a naive regex misses.
check "no_charts_in_features" \
    "Packages/Features/FeatureVitals/Sources/FeatureVitals/LintFixtureDoNotCommit.swift" \
    "Packages/SalusUI/Sources/SalusUI/LintFixtureDoNotCommit.swift" \
    "@preconcurrency import Charts"

# Guard 3: features must not set tab-bar visibility — the shell owns it
# (App/RootView.swift, Android's `showBottomBar` twin). The `.hidden` spelling is
# planted because that is the one a feature actually reaches for when it wants
# the full height for its own screen.
check "no_tab_bar_toolbar_in_features" \
    "Packages/Features/FeatureVitals/Sources/FeatureVitals/LintFixtureDoNotCommit.swift" \
    "Packages/SalusUI/Sources/SalusUI/LintFixtureDoNotCommit.swift" \
    ".toolbar(.hidden, for: .tabBar)"

# ...and the variadic placement list, which is the spelling a feature actually
# reaches for when it wants a FULL-screen screen rather than just the bar gone.
# `for:` takes `ToolbarPlacement...`, so this row is a genuinely different branch
# of the regex from the one above: an anchored `for:\s*\.tabBar` passes the first
# check and misses this one entirely.
check "no_tab_bar_toolbar_in_features" \
    "Packages/Features/FeatureVitals/Sources/FeatureVitals/LintFixtureDoNotCommit.swift" \
    "Packages/SalusUI/Sources/SalusUI/LintFixtureDoNotCommit.swift" \
    ".toolbar(.hidden, for: .navigationBar, .tabBar)"

# Guard 4: a `Calendar` may only be built in the three sanctioned files — days
# are `SalusModel.LocalDate` / `epochDay` everywhere else (CLAUDE.md's LocalDate
# rule). Three lines are planted in ONE fixture, and the assertion is that the
# rule fires EXACTLY twice on it:
#
#   1. `Calendar(identifier: .gregorian)` — the exact spelling every real
#      carve-out uses, so a regex that misses it misses everything.
#   2. `Calendar.autoupdatingCurrent` — the device calendar with neither a
#      construction nor a type annotation to be caught by the other branches.
#      Dropping it from the alternation leaves the easiest way to get a device
#      calendar unguarded, which is exactly why it is planted rather than trusted.
#   3. the substring decoys — `UNCalendarNotificationTrigger`, `CalendarEventDraft`,
#      `addToCalendar`, `calendarDraft`. They must contribute ZERO hits, and the
#      exact count of 2 is what proves it. Without this line the `\b` guard in the
#      regex is asserted only in a YAML comment, and a future edit that drops it
#      would light up FeatureAppointments and FeatureCycle with no test to say so.
#
# The negative half is the five carve-out files themselves: they already build a
# `Calendar` in the tree, and they must stay quiet in this same run or `excluded:`
# has stopped being honoured on a custom rule.
calendar_fixture='let planted = Calendar(identifier: .gregorian)
let live = Calendar.autoupdatingCurrent
func decoy(calendarDraft: CalendarEventDraft, t: UNCalendarNotificationTrigger) { addToCalendar(t) }'

check_carve_out "no_calendar_outside_clock" \
    "Packages/Features/FeatureVitals/Sources/FeatureVitals/LintFixtureDoNotCommit.swift" \
    2 \
    "$calendar_fixture" \
    "Packages/SalusCommon/Sources/SalusCommon/SalusClock.swift" \
    "Packages/SalusReminder/Sources/SalusReminder/platform/UserNotificationGateway.swift" \
    "Packages/SalusUI/Sources/SalusUI/component/SalusWeekdaySymbols.swift" \
    "Packages/SalusUI/Tests/SalusUITests/SalusWeekdaySymbolsTests.swift" \
    "Packages/SalusReminder/Tests/SalusReminderTests/UserNotificationGatewayTests.swift"

echo
if [ "$failures" -gt 0 ]; then
    echo "==> $failures check(s) failed: a custom rule is not doing its job."
    exit 1
fi

echo "==> every custom rule fired in scope and stayed quiet outside it."
