#!/usr/bin/env bash
#
# Moves every smoking timestamp on the booted simulator back by N days, so health stages and
# milestone ladders (day 1, 3, 7 ... 365) can be reached without waiting. Pair it with
# `seed-store-demo.sh`, which seeds the QUIT scenario first; see docs/testing/smoking-testing.md.
#
# The iOS schema is byte-for-byte the Android one, so this runs Android's platform-neutral
# `../salus-android/scripts/dev/smoking_shift.py` on the simulator's `salus.db` instead of keeping a
# second copy in sync (Android's twin is `salus-dev.sh smoking-shift N`). The script shifts the
# `*_ms` / `epoch_day` columns of the five schema-v5 smoking tables inside one transaction, and
# nothing else; each run shifts once (two runs with 7 shift 14 days). Re-seed to start over.
#
# Development builds on the simulator only: the app container is edited directly. The app is
# terminated first (a running GRDB pool would keep its own copy, and the milestone notifications
# were planned from the old times), a timestamped `.bak` of the database is kept next to it, the
# integrity check must pass, and the app is relaunched.
#
# Usage: scripts/dev/smoking-shift.sh [--db <path>] <days>
#
#   <days>       a positive whole number of days
#   --db <path>  shift this SQLite file instead of the booted simulator's database; the simulator
#                is not touched (no terminate, no launch). For dry runs on a scratch copy.
#
# Environment:
#   SALUS_ANDROID_DIR   the Android checkout (default: ../salus-android next to this repository,
#                       which also resolves from a ../wt-<x> worktree). It must be on a branch that
#                       has scripts/dev/smoking_shift.py (feature/m17-smoking-cessation or later).
#
# Exit codes: 0 done, 1 failed (nothing shifted), 2 bad usage.

set -euo pipefail

BUNDLE="com.alicansekban.salus"
DB_REL="Library/Application Support/salus.db"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ANDROID_DIR="${SALUS_ANDROID_DIR:-$REPO_ROOT/../salus-android}"
SHIFT_SCRIPT="$ANDROID_DIR/scripts/dev/smoking_shift.py"

usage() {
    # The header comment is the usage text; print it without the leading "# ".
    sed -n '2,/^set -euo/p' "${BASH_SOURCE[0]}" | sed '$d' | sed 's/^# \{0,1\}//'
}

db=""
days=""
have_days=0
while [[ $# -gt 0 ]]; do
    case "$1" in
        --db)
            [[ $# -ge 2 ]] || { usage >&2; exit 2; }
            db="$2"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        --*)
            echo "unknown option: $1" >&2
            usage >&2
            exit 2
            ;;
        *)
            [[ "$have_days" -eq 0 ]] || { usage >&2; exit 2; }
            days="$1"
            have_days=1
            shift
            ;;
    esac
done

[[ "$have_days" -eq 1 ]] || { usage >&2; exit 2; }
# Validated here as well as in the Python script so a typo never reaches the simulator (no app
# terminate, no backup) — and so the failure reads as a usage error.
case "$days" in
    ''|*[!0-9]*) echo "days must be a positive whole number, got '$days'" >&2; usage >&2; exit 2 ;;
esac
[[ "$((10#$days))" -gt 0 ]] || { echo "days must be greater than 0, got '$days'" >&2; usage >&2; exit 2; }
days="$((10#$days))"

[[ -f "$SHIFT_SCRIPT" ]] || {
    echo "smoking_shift.py not found: $SHIFT_SCRIPT" >&2
    echo "(set SALUS_ANDROID_DIR=<android checkout> on a branch that has it)" >&2
    exit 1
}

on_simulator=0
if [[ -z "$db" ]]; then
    on_simulator=1
    container="$(xcrun simctl get_app_container booted "$BUNDLE" data)"
    db="$container/$DB_REL"
    [[ -f "$db" ]] || { echo "no database yet — launch the app once so it creates $db" >&2; exit 1; }
else
    [[ -f "$db" ]] || { echo "database not found: $db" >&2; exit 1; }
fi

if [[ "$on_simulator" -eq 1 ]]; then
    xcrun simctl terminate booted "$BUNDLE" 2>/dev/null || true
    sleep 1
fi

backup="$db.bak-$(date +%Y%m%d-%H%M%S)"
cp "$db" "$backup"
# The script runs one transaction, so a failure leaves the database as it was; the backup stays.
python3 "$SHIFT_SCRIPT" "$db" "$days" || { echo "shift failed, nothing changed (backup: $backup)" >&2; exit 1; }
sqlite3 "$db" "PRAGMA integrity_check;" | grep -qx ok \
    || { echo "integrity check failed, nothing launched (backup: $backup)" >&2; exit 1; }

if [[ "$on_simulator" -eq 1 ]]; then
    xcrun simctl launch booted "$BUNDLE" >/dev/null
    echo "smoking history moved back $days day(s); the app is starting. Backup: $backup"
else
    echo "smoking history moved back $days day(s) in $db. Backup: $backup"
fi
