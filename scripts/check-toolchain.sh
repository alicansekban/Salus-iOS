#!/bin/bash
#
# Resolves which Xcode to build with, then asserts the three host tools against
# the versions README.md's "Toolchain" table pins. CI and humans call this same
# script; it is step 0 of scripts/ci.sh and of .github/workflows/ci.yml.
#
# Everything below this comment block depends on these three binaries, so a
# mismatch should be visible at the top of the log rather than inferred from a
# lint rule that fired unexpectedly forty lines later.
#
# ---------------------------------------------------------------------------
# The pins — single source of truth for CI
# ---------------------------------------------------------------------------
# These are the values in README.md's Toolchain table. Change them here and
# there in the same commit; nothing else (including the workflow) repeats them.
#
# Xcode is matched on MAJOR.MINOR, not on the exact patch. A patch bump of Xcode
# does not change Swift's language rules or the SDKs this project targets, and
# GitHub rotates macOS image Xcode patches on its own schedule — pinning 26.4.1
# exactly would turn a routine image refresh into a red build for no signal.
# 26.4.x is the pin; 26.5 is not.
#
# SwiftLint and SwiftFormat ARE matched exactly, deliberately. `swiftlint
# --strict` runs on a zero-warning budget, so a patch release that adds or
# tightens a rule is a real, breaking change to this repository's gate, and a
# human should look at it rather than discover it as a mystery failure in the
# Lint step.
README_XCODE="26.4.1"       # matched as 26.4.x
README_SWIFTLINT="0.65.0"   # matched exactly
README_SWIFTFORMAT="0.62.1" # matched exactly

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

expected_xcode_minor="$(printf '%s' "$README_XCODE" | cut -d. -f1,2)"

fail() {
    # `::error::` renders as an annotation on GitHub and as plain text locally.
    echo "::error::$1"
    shift
    for line in "$@"; do echo "$line"; done
    exit 1
}

# ---------------------------------------------------------------------------
# 1. Choose a developer directory
# ---------------------------------------------------------------------------
# Order matters:
#   1. An explicit DEVELOPER_DIR from the environment always wins — a developer
#      who set it meant it, and this script does not second-guess them.
#   2. Otherwise, prefer a versioned Xcode matching the pin under /Applications.
#      This is the GitHub runner shape (`Xcode_26.4.1.app` alongside several
#      other versions, with `Xcode.app` symlinked to a different default). The
#      newest matching patch is taken, so the image may rotate 26.4.1 -> 26.4.2
#      without a commit here.
#   3. Otherwise fall back to whatever `xcode-select` points at. This is the
#      normal laptop shape, where there is one `Xcode.app`.
# If step 3 lands on the wrong version, the assertions below fail loudly; the
# fallback never silently builds with an unpinned toolchain.

if [ -n "${DEVELOPER_DIR:-}" ]; then
    if [ ! -d "$DEVELOPER_DIR" ]; then
        fail "DEVELOPER_DIR is set to '$DEVELOPER_DIR', which does not exist." \
            "Unset it to let this script pick an Xcode, or point it at a real one."
    fi
    developer_dir="$DEVELOPER_DIR"
    source_of_choice="DEVELOPER_DIR from the environment"
else
    # Newest /Applications/Xcode_<pin>*.app, by version sort. The trailing
    # `|| true` is load-bearing: with `pipefail` set, a `ls` that matches
    # nothing makes the whole pipeline non-zero, and `set -e` would abort here
    # instead of falling through to the xcode-select branch below.
    pinned_app="$(
        ls -d "/Applications/Xcode_${expected_xcode_minor}"*.app 2>/dev/null |
            sort -V | tail -1 || true
    )"
    if [ -n "$pinned_app" ]; then
        developer_dir="$pinned_app/Contents/Developer"
        source_of_choice="pinned Xcode ${expected_xcode_minor}.x found at $pinned_app"
    else
        developer_dir="$(xcode-select -p)"
        source_of_choice="xcode-select default (no /Applications/Xcode_${expected_xcode_minor}*.app present)"
    fi
fi

export DEVELOPER_DIR="$developer_dir"
echo "==> Xcode: $source_of_choice"
echo "    DEVELOPER_DIR=$DEVELOPER_DIR"

# Hand the choice to the workflow's later steps. GITHUB_ENV exists only inside
# GitHub Actions; locally this block is skipped and each script resolves the
# same directory the same way.
if [ -n "${GITHUB_ENV:-}" ]; then
    echo "DEVELOPER_DIR=$DEVELOPER_DIR" >>"$GITHUB_ENV"
    echo "    (exported to subsequent workflow steps)"
fi
echo

# ---------------------------------------------------------------------------
# 1b. Put SwiftLint and SwiftFormat on PATH
# ---------------------------------------------------------------------------
# The macos-26 image ships both tools, but the PATH a workflow step starts
# with does not reach Homebrew's bin (CI run #1 died here with
# "swiftlint: command not found"). A laptop usually has `brew shellenv` in its
# profile, which is why the same script passed locally. Prepend the two
# Homebrew prefixes (Apple silicon, Intel) and, only if a tool is still
# missing, install it — the version assertions below still judge the result.
for prefix in /opt/homebrew /usr/local; do
    if [ -d "$prefix/bin" ]; then
        case ":$PATH:" in
            *":$prefix/bin:"*) ;;
            *) PATH="$prefix/bin:$PATH" ;;
        esac
    fi
done
export PATH

if ! command -v swiftlint >/dev/null 2>&1 || ! command -v swiftformat >/dev/null 2>&1; then
    if command -v brew >/dev/null 2>&1; then
        echo "==> swiftlint/swiftformat not on PATH; installing with Homebrew"
        brew install swiftlint swiftformat
    else
        fail "swiftlint or swiftformat is not installed and Homebrew is unavailable." \
            "Install them: brew install swiftlint swiftformat (see README.md, Toolchain)."
    fi
fi
echo "==> swiftlint:   $(command -v swiftlint)"
echo "==> swiftformat: $(command -v swiftformat)"

# Later workflow steps start from the runner's default PATH, so hand them the
# same prefixes. GITHUB_PATH, like GITHUB_ENV, exists only inside Actions.
if [ -n "${GITHUB_PATH:-}" ]; then
    for prefix in /opt/homebrew /usr/local; do
        [ -d "$prefix/bin" ] && echo "$prefix/bin" >>"$GITHUB_PATH"
    done
fi
echo

# ---------------------------------------------------------------------------
# 2. Assert the versions
# ---------------------------------------------------------------------------

xcodebuild -version
swiftlint version
swiftformat --version
echo

actual_xcode="$(xcodebuild -version | head -1 | awk '{print $2}')"
actual_xcode_minor="$(printf '%s' "$actual_xcode" | cut -d. -f1,2)"
actual_swiftlint="$(swiftlint version)"
actual_swiftformat="$(swiftformat --version)"

drift=0
if [ "$actual_xcode_minor" != "$expected_xcode_minor" ]; then
    echo "::error::Xcode $actual_xcode is not ${expected_xcode_minor}.x (README.md pins $README_XCODE)"
    drift=1
fi
if [ "$actual_swiftlint" != "$README_SWIFTLINT" ]; then
    echo "::error::SwiftLint $actual_swiftlint != README.md's $README_SWIFTLINT"
    drift=1
fi
if [ "$actual_swiftformat" != "$README_SWIFTFORMAT" ]; then
    echo "::error::SwiftFormat $actual_swiftformat != README.md's $README_SWIFTFORMAT"
    drift=1
fi

if [ "$drift" -ne 0 ]; then
    echo
    echo "The toolchain drifted from the pins at the top of this script."
    echo
    echo "On a GitHub runner this means the macos-26 image rotated its software."
    echo "Pick the replacement from"
    echo "  https://github.com/actions/runner-images/blob/main/images/macos/macos-26-Readme.md"
    echo "then, IN ONE COMMIT, update all three of:"
    echo "  - README.md              (the Toolchain table)"
    echo "  - scripts/check-toolchain.sh  (the README_* pins at the top)"
    echo "  - whatever the new version broke"
    echo "Re-run scripts/ci.sh locally on the new version before pushing: a"
    echo "SwiftLint bump in particular can add rules that --strict then rejects."
    echo
    echo "Installed Xcodes on this machine:"
    ls -1 /Applications 2>/dev/null | grep -i '^Xcode' || echo "  (none found under /Applications)"
    exit 1
fi

echo "==> Toolchain matches README.md."
