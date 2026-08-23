#!/bin/bash
#
# Removes every build artefact this repository produces, and prints what it
# removed. The twin of Android's `./gradlew clean`.
#
# There are exactly two kinds of artefact, and they live in two different
# places, which is the whole reason this script exists:
#
#   1. `.build` and `.swiftpm` inside every package — SwiftPM's per-package
#      build directory and its per-package IDE state, written by
#      `scripts/test-packages.sh` (24 of each, so removing them by hand is 48
#      paths, ten of them nested one level deeper under `Packages/Features/`).
#      `.build` also holds the resolved GRDB checkout, so the next
#      `swift test` re-fetches it; that is the point of a clean, not a
#      surprise.
#
#   2. This project's DerivedData directory — written by
#      `scripts/build-app.sh`, and NOT inside the repository: Xcode puts it
#      under ~/Library/Developer/Xcode/DerivedData/Salus-<hash>, where the
#      hash depends on the project's path and cannot be predicted. It is read
#      out of `xcodebuild -showBuildSettings` instead of guessed, so a machine
#      with a custom DerivedData location (Xcode ▸ Settings ▸ Locations) is
#      cleaned correctly too. `BUILD_DIR` is `<derived>/Build/Products`, so
#      the directory to remove is two levels up from it.
#
# The DerivedData path is the one `rm -rf` here that points outside the
# repository, so it is removed only after it is checked to sit under a
# directory named DerivedData AND to be named after this project. A machine
# without the pinned Xcode selected (or without Xcode at all) still gets the
# package caches cleaned: the lookup warns and is skipped rather than failing
# the script.
#
# One quirk worth knowing before it looks like a bug: reading `BUILD_DIR`
# means running `xcodebuild`, and `xcodebuild` recreates the DerivedData
# directory — and a `.swiftpm` marker inside each local package — in order to
# answer. A second consecutive run therefore still reports those as removed.
# They are what the lookup itself just made, not stale artefacts.
#
# Written for bash 3.2 (what macOS and the GitHub runners ship), like the
# other scripts here.
#
# Usage:
#   scripts/clean.sh

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

removed_count=0

# Removes one directory and reports it with its size. A path that is not there
# is not an error — a clean tree is the state this script is trying to reach.
remove_directory() {
    directory="$1"
    [ -d "$directory" ] || return 0

    size="$(du -sh "$directory" 2>/dev/null | cut -f1)"
    rm -rf "$directory"
    printf '    removed %-6s %s\n' "${size:-?}" "${directory#"$REPO_ROOT"/}"
    removed_count=$((removed_count + 1))
}

# Discovered by manifest, exactly as scripts/test-packages.sh does, so the ten
# packages nested under Packages/Features/ are covered and a new package needs
# no edit here. `.build` is pruned from the search: SwiftPM checkouts hold
# manifests of their own.
echo "==> SwiftPM package artefacts (.build, .swiftpm under every package)"
while IFS= read -r package_dir; do
    [ -n "$package_dir" ] || continue
    remove_directory "$package_dir/.build"
    remove_directory "$package_dir/.swiftpm"
done <<EOF
$(find Packages -name Package.swift -not -path '*/.build/*' -exec dirname {} \; | sort)
EOF

echo
echo "==> Xcode DerivedData for this project"
# `if !` rather than a bare assignment, deliberately: under `set -e` a command
# substitution that fails takes the whole script down with it, so the warning
# below would be dead code exactly when it is wanted (no xcodebuild on PATH ->
# 127, no Xcode selected or a bad scheme -> 66/1). Guarding the command makes
# its failure a value instead of an exit. The settings are captured whole and
# filtered afterwards, rather than piped straight into awk, so that awk cannot
# close the pipe early and leave xcodebuild killed by SIGPIPE (141) — which is
# invisible while the output fits the pipe buffer and starts happening when it
# no longer does.
if ! build_settings="$(xcodebuild -project Salus.xcodeproj -scheme Salus -showBuildSettings 2>/dev/null)"; then
    build_settings=""
fi
build_dir="$(printf '%s\n' "$build_settings" | awk -F' = ' '/^ *BUILD_DIR = /{value=$2} END{print value}')"

if [ -z "$build_dir" ]; then
    echo "    skipped: could not read BUILD_DIR from xcodebuild" >&2
    echo "             (run scripts/check-toolchain.sh — the packages above were still cleaned)" >&2
else
    derived_dir="$(dirname "$(dirname "$build_dir")")"
    case "$derived_dir" in
    */DerivedData/Salus-*)
        remove_directory "$derived_dir"
        ;;
    *)
        echo "    skipped: $derived_dir is not a DerivedData directory for this project" >&2
        ;;
    esac
fi

echo
if [ "$removed_count" -eq 0 ]; then
    echo "==> nothing to remove — the tree is already clean"
else
    echo "==> removed $removed_count director(ies)"
fi
