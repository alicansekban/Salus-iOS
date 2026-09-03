#!/usr/bin/env bash
#
# Fills the Salus database on the booted simulator or a paired iPhone with realistic health
# records so the AI summary and doctor report have enough distinct days to run (3 of 7 weekly,
# 7 of 30 monthly).
#
# The iOS schema is byte-for-byte the Android one (same tables, columns and enum strings), so
# this reuses the Android seeder instead of keeping a second copy in sync:
# `../salus-android/scripts/dev/seed_health_data.py`. Override with SEED_SCRIPT=<path>.
#
# Development builds only: the simulator's app container is read directly, a device's through
# `devicectl … appDataContainer`, which Xcode-installed (development-signed) apps allow and store
# builds do not. The app is terminated first, a timestamped `.bak` of the database is kept, and
# the app is relaunched at the end.
#
# Usage:
#   scripts/dev/seed-health-data.sh [days]                       booted simulator (default 30)
#   scripts/dev/seed-health-data.sh --device [days]              the first paired iPhone
#   scripts/dev/seed-health-data.sh --device <udid> [days]       a specific device

set -euo pipefail

BUNDLE="com.alicansekban.salus"
DB_REL="Library/Application Support/salus.db"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SEED_SCRIPT="${SEED_SCRIPT:-$REPO_ROOT/../salus-android/scripts/dev/seed_health_data.py}"
WORK_DIR="${TMPDIR:-/tmp}/salus-ios-dev"

[[ -f "$SEED_SCRIPT" ]] || { echo "seeder not found: $SEED_SCRIPT (set SEED_SCRIPT=…)"; exit 1; }

target="simulator"; udid=""; days="30"
if [[ "${1:-}" == "--device" ]]; then
    target="device"; shift
    if [[ "${1:-}" =~ ^[0-9A-Fa-f-]{20,}$ ]]; then udid="$1"; shift; fi
fi
days="${1:-30}"

# Seconds east of UTC on this Mac; the seeder derives local timestamps from it, the way the
# Android script does from the emulator's zone.
tz_offset="$(python3 -c 'import time; print(-time.altzone if time.daylight and time.localtime().tm_isdst else -time.timezone)')"

seed_file() {
    cp "$1" "$1.bak-$(date +%Y%m%d-%H%M%S)"
    python3 "$SEED_SCRIPT" "$1" "$days" "$tz_offset"
    sqlite3 "$1" "PRAGMA integrity_check;" | grep -qx ok || { echo "integrity check failed, nothing pushed"; exit 1; }
}

if [[ "$target" == "simulator" ]]; then
    container="$(xcrun simctl get_app_container booted "$BUNDLE" data)"
    db="$container/$DB_REL"
    [[ -f "$db" ]] || { echo "no database yet — launch the app once so it creates $db"; exit 1; }
    xcrun simctl terminate booted "$BUNDLE" 2>/dev/null || true
    sleep 1
    seed_file "$db"
    xcrun simctl launch booted "$BUNDLE" >/dev/null
    echo "seeded the simulator. Open the AI summary."
else
    devicectl() { xcrun devicectl "$@" 2> >(grep -v "provisioning paramter list" >&2); }
    if [[ -z "$udid" ]]; then
        # The identifier column is the only UUID-shaped token on a paired row.
        udid="$(devicectl list devices 2>/dev/null | grep 'available (paired)' \
            | grep -oE '[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}' | head -1)"
    fi
    [[ -n "$udid" ]] || { echo "no paired iPhone found (xcrun devicectl list devices)"; exit 1; }
    mkdir -p "$WORK_DIR"
    db="$WORK_DIR/device-salus.db"
    pid="$(devicectl device info processes --device "$udid" 2>/dev/null | awk '/Salus\.app\/Salus$/ {print $1; exit}' || true)"
    [[ -n "$pid" ]] && devicectl device process terminate --device "$udid" --pid "$pid" >/dev/null 2>&1 || true
    sleep 1
    devicectl device copy from --device "$udid" --domain-type appDataContainer --domain-identifier "$BUNDLE" \
        --source "$DB_REL" --destination "$db" >/dev/null
    seed_file "$db"
    devicectl device copy to --device "$udid" --domain-type appDataContainer --domain-identifier "$BUNDLE" \
        --source "$db" --destination "$DB_REL" >/dev/null
    devicectl device process launch --device "$udid" "$BUNDLE" >/dev/null
    echo "seeded device $udid. Open the AI summary."
fi
