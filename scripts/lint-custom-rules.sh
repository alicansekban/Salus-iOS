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

# plant <path> <import-line>
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

echo
if [ "$failures" -gt 0 ]; then
    echo "==> $failures check(s) failed: a custom rule is not doing its job."
    exit 1
fi

echo "==> every custom rule fired in scope and stayed quiet outside it."
