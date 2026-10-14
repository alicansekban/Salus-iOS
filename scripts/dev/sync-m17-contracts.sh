#!/usr/bin/env bash
#
# Copies the iOS-M17 contract files that the Android session produces into this repository's test
# resources, and reports which of the four parallel-runbook sync points (S1-S4) are reached.
#
# Everything is read from the committed Android branch (`git -C <android> show <branch>:<path>`),
# never from the Android working tree: that tree is being edited by the Android session, and a
# half-written file must not become a "contract". Nothing here writes in the Android repository.
#
# A file that is not on the branch yet is not an error: it prints "not yet on branch (sync point
# open)" and the run goes on (plan ruling P4 — an open sync point never blocks the other steps).
#
# Copies (source on the branch -> destination here):
#   S3  docs/contracts/smoking-golden-vectors.json
#         -> Packages/SalusSmoking/Tests/SalusSmokingTests/Resources/smoking-golden-vectors.json
#   S2  core/database/schemas/com.alicansekban.salus.core.database.SalusDatabase/5.json
#         -> Packages/SalusDatabase/Tests/SalusDatabaseTests/Resources/RoomSchemas/5.json
#
# Sync points reported by --status:
#   S1  docs/design/design-tokens.md mentions "smoking" (case-insensitive)
#   S2  the version-5 Room schema exists
#   S3  the golden-vector file exists
#   S4  scripts/dev/smoking_shift.py exists
#
# Environment:
#   SALUS_ANDROID_DIR      the Android checkout (default: ../salus-android next to this repository,
#                          which also resolves from a ../wt-m17-i<N> worktree)
#   SALUS_ANDROID_BRANCH   the branch to read (default: feature/m17-smoking-cessation)
#
# Usage:
#   scripts/dev/sync-m17-contracts.sh            copy every file that is on the branch
#   scripts/dev/sync-m17-contracts.sh --check    diff the copies against the branch; exit 1 on drift
#   scripts/dev/sync-m17-contracts.sh --status   print S1-S4 as reached / open; always exit 0
#
# Exit codes: 0 done (or nothing to do), 1 drift (--check only), 2 bad usage or no Android checkout.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ANDROID_DIR="${SALUS_ANDROID_DIR:-$REPO_ROOT/../salus-android}"
BRANCH="${SALUS_ANDROID_BRANCH:-feature/m17-smoking-cessation}"

TOKENS_SRC="docs/design/design-tokens.md"
SCHEMA_SRC="core/database/schemas/com.alicansekban.salus.core.database.SalusDatabase/5.json"
VECTORS_SRC="docs/contracts/smoking-golden-vectors.json"
SHIFT_SRC="scripts/dev/smoking_shift.py"

# "<sync point>|<source on the branch>|<destination under the repo root>"
COPIES=(
    "S3|$VECTORS_SRC|Packages/SalusSmoking/Tests/SalusSmokingTests/Resources/smoking-golden-vectors.json"
    "S2|$SCHEMA_SRC|Packages/SalusDatabase/Tests/SalusDatabaseTests/Resources/RoomSchemas/5.json"
)

usage() {
    # The header comment is the usage text; print it without the leading "# ".
    sed -n '2,/^set -euo/p' "${BASH_SOURCE[0]}" | sed '$d' | sed 's/^# \{0,1\}//'
}

mode="sync"
case "${1:-}" in
    "") ;;
    --check) mode="check" ;;
    --status) mode="status" ;;
    -h | --help) usage; exit 0 ;;
    *) echo "unknown argument: $1" >&2; usage >&2; exit 2 ;;
esac
[[ $# -le 1 ]] || { usage >&2; exit 2; }

# True when <path> is committed on the branch. A missing checkout or branch is "not there".
on_branch() {
    git -C "$ANDROID_DIR" cat-file -e "$BRANCH:$1" 2>/dev/null
}

branch_ready() {
    git -C "$ANDROID_DIR" rev-parse --verify --quiet "$BRANCH^{commit}" >/dev/null 2>&1
}

# Prints the branch's copy of <path>; callers check on_branch first.
branch_show() {
    git -C "$ANDROID_DIR" show "$BRANCH:$1"
}

report_status() {
    local s1="open" s2="open" s3="open" s4="open" tokens
    if branch_ready; then
        # Capture first: `grep -q` closing the pipe early would make `git show` fail under pipefail.
        if on_branch "$TOKENS_SRC" && tokens="$(branch_show "$TOKENS_SRC")" && grep -qi smoking <<<"$tokens"; then
            s1="reached"
        fi
        ! on_branch "$SCHEMA_SRC" || s2="reached"
        ! on_branch "$VECTORS_SRC" || s3="reached"
        ! on_branch "$SHIFT_SRC" || s4="reached"
    else
        echo "note: $BRANCH not found in $ANDROID_DIR — every sync point reads as open" >&2
    fi
    echo "S1: $s1 (smoking accent in $TOKENS_SRC)"
    echo "S2: $s2 ($SCHEMA_SRC)"
    echo "S3: $s3 ($VECTORS_SRC)"
    echo "S4: $s4 ($SHIFT_SRC)"
}

if [[ "$mode" == "status" ]]; then
    report_status
    exit 0
fi

[[ -d "$ANDROID_DIR" ]] || { echo "Android checkout not found: $ANDROID_DIR (set SALUS_ANDROID_DIR=…)" >&2; exit 2; }
branch_ready || { echo "branch not found in $ANDROID_DIR: $BRANCH (set SALUS_ANDROID_BRANCH=…)" >&2; exit 2; }

tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT

drift=0
for entry in "${COPIES[@]}"; do
    IFS='|' read -r point src dst <<<"$entry"
    name="$(basename "$dst")"
    if ! on_branch "$src"; then
        echo "$point $name: not yet on branch (sync point open)"
        continue
    fi
    branch_show "$src" >"$tmp"
    dest="$REPO_ROOT/$dst"
    if [[ "$mode" == "check" ]]; then
        if [[ ! -f "$dest" ]]; then
            echo "$point $name: drift — $dst is missing, run scripts/dev/sync-m17-contracts.sh"
            drift=1
        elif ! cmp -s "$tmp" "$dest"; then
            echo "$point $name: drift — $dst differs from $BRANCH, run scripts/dev/sync-m17-contracts.sh"
            drift=1
        else
            echo "$point $name: in sync"
        fi
    elif [[ -f "$dest" ]] && cmp -s "$tmp" "$dest"; then
        echo "$point $name: unchanged"
    else
        mkdir -p "$(dirname "$dest")"
        cp "$tmp" "$dest"
        echo "$point $name: copied ($(wc -c <"$dest" | tr -d ' ') bytes) -> $dst"
    fi
done
exit "$drift"
