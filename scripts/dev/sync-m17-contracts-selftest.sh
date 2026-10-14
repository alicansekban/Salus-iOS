#!/usr/bin/env bash
# Self-test for scripts/dev/sync-m17-contracts.sh. It copies the script into a scratch "iOS repo"
# and points SALUS_ANDROID_DIR at a scratch git repository that plays the Android checkout, so
# nothing here reads or writes the real `../salus-android`.
#
# usage: bash scripts/dev/sync-m17-contracts-selftest.sh   (from any directory)
set -u

here="$(cd "$(dirname "$0")" && pwd)"
SCRIPT="$here/sync-m17-contracts.sh"
scratch="$(mktemp -d)"
trap 'rm -rf "$scratch"' EXIT

passed=0
failed=0
n=0
OUT=""
CODE=0
IOS=""
ANDROID=""

VEC_SRC="docs/contracts/smoking-golden-vectors.json"
SCHEMA_SRC="core/database/schemas/com.alicansekban.salus.core.database.SalusDatabase/5.json"
VEC_DST="Packages/SalusSmoking/Tests/SalusSmokingTests/Resources/smoking-golden-vectors.json"
SCHEMA_DST="Packages/SalusDatabase/Tests/SalusDatabaseTests/Resources/RoomSchemas/5.json"
BRANCH="feature/m17-smoking-cessation"

fail() { echo "FAIL $1"; failed=$((failed + 1)); }
pass() { passed=$((passed + 1)); }

check_code() { # <name> <expected>
    if [[ "$CODE" == "$2" ]]; then pass; else fail "$1: exit $CODE, expected $2"; fi
}
check_out() { # <name> <fixed string that must appear in the output>
    if [[ "$OUT" == *"$2"* ]]; then pass; else fail "$1: output lacks '$2' — got: $OUT"; fi
}
check_no_out() { # <name> <fixed string that must not appear>
    if [[ "$OUT" != *"$2"* ]]; then pass; else fail "$1: output has '$2' — got: $OUT"; fi
}
check_file() { # <name> <path> <expected content>
    if [[ -f "$2" && "$(cat "$2")" == "$3" ]]; then pass; else fail "$1: $2 is not '$3'"; fi
}
check_absent() { # <name> <path>
    if [[ ! -e "$2" ]]; then pass; else fail "$1: $2 exists"; fi
}

# A fresh pair: an iOS tree holding a copy of the script, and an Android repo on the M17 branch
# with one initial commit (the branch exists, but none of S1-S4 is reached yet).
newpair() {
    n=$((n + 1))
    IOS="$scratch/t$n/ios"
    ANDROID="$scratch/t$n/android"
    mkdir -p "$IOS/scripts/dev" "$ANDROID/docs/design"
    cp "$SCRIPT" "$IOS/scripts/dev/sync-m17-contracts.sh" 2>/dev/null || true
    git -C "$ANDROID" init -q -b "$BRANCH"
    git -C "$ANDROID" config user.email t@example.com
    git -C "$ANDROID" config user.name t
    printf '# tokens\n\nmedications only\n' >"$ANDROID/docs/design/design-tokens.md"
    git -C "$ANDROID" add -A
    git -C "$ANDROID" commit -q -m init
}

# android_commit <path> <content>: commit one file on the branch.
android_commit() {
    mkdir -p "$(dirname "$ANDROID/$1")"
    printf '%s' "$2" >"$ANDROID/$1"
    git -C "$ANDROID" add -A
    git -C "$ANDROID" commit -q -m "add $1"
}

run() { # <args...> — runs the copied script against the scratch pair
    OUT="$(SALUS_ANDROID_DIR="$ANDROID" bash "$IOS/scripts/dev/sync-m17-contracts.sh" "$@" 2>&1)"
    CODE=$?
}

# 1. Nothing reached: default run says "open" for both files, copies nothing, exits 0.
newpair
run
check_code "default, nothing reached, exits 0" 0
check_out "default, nothing reached, names the open state" "not yet on branch (sync point open)"
check_absent "default, nothing reached, no vectors copy" "$IOS/$VEC_DST"
check_absent "default, nothing reached, no schema copy" "$IOS/$SCHEMA_DST"

# 2. --check with nothing reached never fails: nothing to drift from.
newpair
run --check
check_code "--check, nothing reached, exits 0" 0
check_out "--check, nothing reached, says open" "not yet on branch (sync point open)"

# 3. --status with nothing reached: four open lines, exit 0.
newpair
run --status
check_code "--status, nothing reached, exits 0" 0
for s in S1 S2 S3 S4; do check_out "--status lists $s open" "$s: open"; done
check_no_out "--status reports none reached" ": reached"

# 4. The committed branch is read, never the working tree: an untracked file does not count.
newpair
mkdir -p "$ANDROID/docs/contracts"
printf '{"working":"tree"}' >"$ANDROID/$VEC_SRC"
run
check_out "untracked source is still open" "not yet on branch (sync point open)"
check_absent "untracked source is not copied" "$IOS/$VEC_DST"
run --status
check_out "untracked source leaves S3 open" "S3: open"

# 5. A source committed on the branch is copied byte for byte; a re-run reports unchanged.
newpair
android_commit "$VEC_SRC" '{"vectors":[1,2,3]}'
android_commit "$SCHEMA_SRC" '{"formatVersion":1,"version":5}'
run
check_code "sync, both reached, exits 0" 0
check_file "vectors copied verbatim" "$IOS/$VEC_DST" '{"vectors":[1,2,3]}'
check_file "schema copied verbatim" "$IOS/$SCHEMA_DST" '{"formatVersion":1,"version":5}'
check_out "sync says copied" "copied"
run
check_out "second sync says unchanged" "unchanged"
run --check
check_code "--check after sync exits 0" 0

# 6. Working-tree edits after the commit do not leak into the copy.
newpair
android_commit "$VEC_SRC" '{"v":"committed"}'
printf '{"v":"dirty"}' >"$ANDROID/$VEC_SRC"
run
check_file "copy follows the commit, not the dirty tree" "$IOS/$VEC_DST" '{"v":"committed"}'

# 7. --check: drift in a copy exits 1 and names the file; it does not rewrite the copy.
newpair
android_commit "$VEC_SRC" '{"v":1}'
run
printf '{"v":"stale"}' >"$IOS/$VEC_DST"
run --check
check_code "--check on drift exits 1" 1
check_out "--check names the drifted file" "smoking-golden-vectors.json"
check_out "--check says drift" "drift"
check_file "--check leaves the copy alone" "$IOS/$VEC_DST" '{"v":"stale"}'

# 8. --check: a reached source with no copy yet is drift too; an open source stays quiet.
newpair
android_commit "$SCHEMA_SRC" '{"version":5}'
run --check
check_code "--check, source reached but never copied, exits 1" 1
check_out "--check names the missing copy" "5.json"
check_out "--check keeps the other file open" "not yet on branch (sync point open)"

# 9. --status flips to reached per sync point, from the branch alone.
newpair
printf '# tokens\n\nSmoking accent: #123456\n' >"$ANDROID/docs/design/design-tokens.md"
git -C "$ANDROID" commit -q -am "tokens"
android_commit "$SCHEMA_SRC" '{"version":5}'
android_commit "$VEC_SRC" '{"v":1}'
android_commit "scripts/dev/smoking_shift.py" 'print(1)'
run --status
check_code "--status, all reached, exits 0" 0
for s in S1 S2 S3 S4; do check_out "--status lists $s reached" "$s: reached"; done
check_no_out "--status leaves nothing open" ": open"

# 10. S1 is the token doc mentioning "smoking" case-insensitively, not mere file existence.
newpair
run --status
check_out "S1 open while the tokens doc does not mention smoking" "S1: open"
printf '# tokens\n\nSMOKING accent\n' >"$ANDROID/docs/design/design-tokens.md"
git -C "$ANDROID" commit -q -am "tokens"
run --status
check_out "S1 reached on an upper-case mention" "S1: reached"

# 11. --status never fails, even when the Android checkout or the branch is missing.
newpair
OUT="$(SALUS_ANDROID_DIR="$scratch/nowhere" bash "$IOS/scripts/dev/sync-m17-contracts.sh" --status 2>&1)"
CODE=$?
check_code "--status without an Android checkout exits 0" 0
check_out "--status without an Android checkout says open" "S1: open"

# 12. A bad flag exits 2 with the usage text.
newpair
run --nope
check_code "unknown flag exits 2" 2
check_out "unknown flag prints usage" "Usage"

echo "sync-m17-contracts-selftest: $passed passed, $failed failed"
[[ "$failed" -eq 0 ]]
