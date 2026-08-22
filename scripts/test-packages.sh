#!/bin/bash
#
# Runs `swift test` for every local SwiftPM package under Packages/.
#
# CI and humans call the same script, so a green local run means the same
# commands passed that the workflow will run (.github/workflows/ci.yml calls
# this file directly). Exits non-zero if ANY package fails, but only after
# running all of them — one broken placeholder should not hide the state of
# the other 23.
#
# The packages are built for the HOST (macOS) toolchain, because `swift test`
# cannot run a test bundle on an iOS simulator. That is why iOS-only packages
# whose code touches SwiftUI also declare `.macOS(.v14)` in their manifest —
# see the comment in Packages/SalusDesignSystem/Package.swift. iOS 17 remains
# the ship target; the iOS build of every package is covered by the xcodebuild
# step on the app scheme, which links them all.
#
# Written for bash 3.2 (the /bin/bash macOS and the GitHub macOS runners ship),
# so: no `mapfile`, no empty-array expansion under `set -u`.
#
# Usage:
#   scripts/test-packages.sh              # test every package
#   scripts/test-packages.sh SalusModel   # test only the named package(s)

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT" || exit 1

# Discover packages by manifest so a new package is picked up with no edit
# here. `.build` is pruned: SwiftPM checkouts hold manifests of their own.
all_dirs="$(find Packages -name Package.swift -not -path '*/.build/*' -exec dirname {} \; | sort)"

# Discovering nothing must never read as "everything passed". Without this the
# script would print "0/0 packages passed" and exit 0 — a green CI run that
# tested not one line of code, which is the worst failure mode a test gate has.
# Reachable for real: a bad `cd`, a checkout that did not fetch Packages/, or
# someone moving the directory.
if [ -z "$all_dirs" ]; then
    echo "error: found no Package.swift under $REPO_ROOT/Packages" >&2
    echo "       Expected 24 local packages. Refusing to report success on an" >&2
    echo "       empty set — check the working directory and the checkout." >&2
    exit 2
fi

if [ "$#" -gt 0 ]; then
    dirs=""
    for want in "$@"; do
        match="$(printf '%s\n' "$all_dirs" | while IFS= read -r dir; do
            [ "$(basename "$dir")" = "$want" ] && printf '%s\n' "$dir"
        done)"
        if [ -z "$match" ]; then
            echo "error: no package named '$want' under Packages/" >&2
            exit 2
        fi
        dirs="$(printf '%s\n%s' "$dirs" "$match")"
    done
    dirs="$(printf '%s\n' "$dirs" | grep -v '^$')"
else
    dirs="$all_dirs"
fi

total="$(printf '%s\n' "$dirs" | grep -c '^')"
echo "==> swift test across $total package(s)"
echo

failed=""
failed_count=0
index=0

while IFS= read -r dir; do
    index=$((index + 1))
    name="$(basename "$dir")"
    printf '::group::[%2d/%s] %s\n' "$index" "$total" "$name"

    if (cd "$dir" && swift test); then
        printf '::endgroup::\n'
        printf 'PASS  %s\n\n' "$name"
    else
        printf '::endgroup::\n'
        printf 'FAIL  %s\n\n' "$name"
        failed="$failed  - $name
"
        failed_count=$((failed_count + 1))
    fi
done <<EOF
$dirs
EOF

echo "==> summary: $((total - failed_count))/$total packages passed"

if [ "$failed_count" -gt 0 ]; then
    echo "==> failing packages:"
    printf '%s' "$failed"
    exit 1
fi
