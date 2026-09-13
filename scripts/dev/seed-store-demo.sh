#!/usr/bin/env bash
#
# Replaces every health row on the booted simulator with the store-screenshot dataset ("Ayşe"):
# a female profile so the cycle tracker shows under More, four medications with today's doses
# partly taken, upcoming appointments, two months of vitals and four regular cycles.
#
# The iOS schema is byte-for-byte the Android one, so this reuses the Android seeder instead of
# keeping a second copy in sync: `../salus-android/scripts/dev/seed_store_demo.py`
# (override with SEED_SCRIPT=<path>). Android's twin is `salus-dev.sh demo`, so both stores show
# the same person. Details: ../salus-android/docs/testing/store-demo-data.md
#
# Development builds on the simulator only: the app container is edited directly. Onboarding must
# already be completed (the seeder rewrites the profile row, it does not create the flag). The app
# is terminated first, a timestamped `.bak` of the database is kept, and the app is relaunched.
#
# Usage: scripts/dev/seed-store-demo.sh [--lang tr|en]        (default: tr)

set -euo pipefail

BUNDLE="com.alicansekban.salus"
DB_REL="Library/Application Support/salus.db"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SEED_SCRIPT="${SEED_SCRIPT:-$REPO_ROOT/../salus-android/scripts/dev/seed_store_demo.py}"

[[ -f "$SEED_SCRIPT" ]] || { echo "seeder not found: $SEED_SCRIPT (set SEED_SCRIPT=…)"; exit 1; }

# The simulator runs in the Mac's zone; the seeder derives local timestamps and the tz_id column
# from it, the way the Android script does from the emulator's zone.
tz_id="$(readlink /etc/localtime | sed 's#.*/zoneinfo/##')"
[[ -n "$tz_id" ]] || tz_id="Europe/Istanbul"
tz_offset="$(python3 -c 'import time; print(-time.altzone if time.daylight and time.localtime().tm_isdst else -time.timezone)')"

container="$(xcrun simctl get_app_container booted "$BUNDLE" data)"
db="$container/$DB_REL"
[[ -f "$db" ]] || { echo "no database yet — launch the app once so it creates $db"; exit 1; }

if [[ "$(xcrun simctl spawn booted defaults read "$BUNDLE" onboarding_completed 2>/dev/null || echo 0)" != "1" ]]; then
    echo "complete onboarding in the app first, then run this again."
    exit 1
fi

xcrun simctl terminate booted "$BUNDLE" 2>/dev/null || true
sleep 1
cp "$db" "$db.bak-$(date +%Y%m%d-%H%M%S)"
python3 "$SEED_SCRIPT" "$db" "$tz_id" "$tz_offset" "$@"
sqlite3 "$db" "PRAGMA integrity_check;" | grep -qx ok || { echo "integrity check failed, nothing launched"; exit 1; }
xcrun simctl launch booted "$BUNDLE" >/dev/null
echo "demo data loaded on the simulator; the app is starting."
