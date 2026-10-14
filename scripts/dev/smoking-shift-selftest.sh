#!/usr/bin/env bash
# Self-test for scripts/dev/smoking-shift.sh. It runs the wrapper with `--db` against scratch SQLite
# files built from the committed Room v5 schema export, so no simulator and no app container is
# touched. The Android shift script and the schema are read with `git show` from the committed M17
# branch (never from the Android working tree) into a scratch "Android checkout".
#
# usage: bash scripts/dev/smoking-shift-selftest.sh   (from any directory)
set -u

here="$(cd "$(dirname "$0")" && pwd)"
SCRIPT="$here/smoking-shift.sh"
REPO_ROOT="$(cd "$here/../.." && pwd)"
REAL_ANDROID="${SALUS_ANDROID_DIR:-$REPO_ROOT/../salus-android}"
BRANCH="${SALUS_ANDROID_BRANCH:-feature/m17-smoking-cessation}"
SCHEMA_SRC="core/database/schemas/com.alicansekban.salus.core.database.SalusDatabase/5.json"
SHIFT_SRC="scripts/dev/smoking_shift.py"
DAY_MS=86400000

scratch="$(mktemp -d)"
trap 'rm -rf "$scratch"' EXIT

passed=0
failed=0
OUT=""
CODE=0

fail() { echo "FAIL $1"; failed=$((failed + 1)); }
pass() { passed=$((passed + 1)); }
check_code() { if [[ "$CODE" == "$2" ]]; then pass; else fail "$1: exit $CODE, expected $2 — $OUT"; fi; }
check_nonzero() { if [[ "$CODE" != "0" ]]; then pass; else fail "$1: exit 0, expected non-zero — $OUT"; fi; }
check_out() { if [[ "$OUT" == *"$2"* ]]; then pass; else fail "$1: output lacks '$2' — got: $OUT"; fi; }
check_eq() { if [[ "$2" == "$3" ]]; then pass; else fail "$1: got '$2', expected '$3'"; fi; }

# Source material from the committed branch; if the branch lacks either file the sync point S4/S2 is
# open and this test cannot run — say so instead of passing vacuously.
android="$scratch/android"
mkdir -p "$android/scripts/dev"
if ! git -C "$REAL_ANDROID" show "$BRANCH:$SHIFT_SRC" >"$android/$SHIFT_SRC" 2>/dev/null \
    || ! git -C "$REAL_ANDROID" show "$BRANCH:$SCHEMA_SRC" >"$scratch/5.json" 2>/dev/null; then
    echo "smoking-shift-selftest: $SHIFT_SRC or the v5 schema is not on $BRANCH yet (sync point open); nothing to test"
    exit 1
fi

# newdb <name>: a database with every table of the v5 export, one row in each smoking table.
newdb() {
    local db="$scratch/$1.db"
    python3 - "$scratch/5.json" "$db" <<'PY'
import json, sqlite3, sys
entities = json.load(open(sys.argv[1]))["database"]["entities"]
con = sqlite3.connect(sys.argv[2])
for e in entities:
    con.execute(e["createSql"].replace("${TABLE_NAME}", e["tableName"]))
con.executescript("""
INSERT INTO smoking_plan VALUES ('plan-1','QUIT','CIGARETTE',15,NULL,'TRY','reason',1,0,1000000000000,'Europe/Istanbul');
INSERT INTO smoking_price_period VALUES ('price-1',20000,450);
INSERT INTO smoking_quit_attempt VALUES ('att-1',1000000000000,'Europe/Istanbul',NULL,NULL);
INSERT INTO smoking_event VALUES ('ev-1','SMOKED',1000000500000,'Europe/Istanbul',11574,2,'STRESS',4,'CIGARETTE','att-1');
""")
con.commit()
PY
    echo "$db"
}

sql() { sqlite3 "$1" "$2"; }

run() { # <args...>
    OUT="$(SALUS_ANDROID_DIR="$android" bash "$SCRIPT" "$@" 2>&1)"
    CODE=$?
}

# 1. No argument, and bad day counts: exit 2 with usage, and the database is not touched.
db="$(newdb t1)"
before="$(sql "$db" 'SELECT started_at_ms FROM smoking_quit_attempt')"
run --db "$db"
check_code "no days exits 2" 2
check_out "no days prints usage" "Usage"
for bad in 0 -3 abc 1.5 ""; do
    run --db "$db" "$bad"
    check_code "days '$bad' exits 2" 2
done
check_eq "bad days leave the database alone" "$(sql "$db" 'SELECT started_at_ms FROM smoking_quit_attempt')" "$before"
run --nope 3
check_code "unknown flag exits 2" 2

# 2. A missing database or a missing Android script is a clear error, not a traceback.
run --db "$scratch/nowhere.db" 3
check_code "missing --db file exits 1" 1
check_out "missing --db file is named" "database not found"
OUT="$(SALUS_ANDROID_DIR="$scratch/nowhere" bash "$SCRIPT" --db "$db" 3 2>&1)"
CODE=$?
check_code "missing Android script exits 1" 1
check_out "missing Android script is named" "smoking_shift.py not found"

# 3. The shift: smoking columns move, nothing else does, the .bak holds the original.
db="$(newdb t3)"
run --db "$db" 7
check_code "shift 7 exits 0" 0
check_eq "plan created_at_ms moved" "$(sql "$db" 'SELECT created_at_ms FROM smoking_plan')" "$((1000000000000 - 7 * DAY_MS))"
check_eq "attempt started_at_ms moved" "$(sql "$db" 'SELECT started_at_ms FROM smoking_quit_attempt')" "$((1000000000000 - 7 * DAY_MS))"
check_eq "event epoch_day moved" "$(sql "$db" 'SELECT epoch_day FROM smoking_event')" "$((11574 - 7))"
check_eq "price period day moved" "$(sql "$db" 'SELECT effective_from_epoch_day FROM smoking_price_period')" "$((20000 - 7))"
check_eq "attempt NULL end stays NULL" "$(sql "$db" 'SELECT ended_at_ms IS NULL FROM smoking_quit_attempt')" "1"
check_eq "unit cost untouched" "$(sql "$db" 'SELECT unit_cost_minor FROM smoking_price_period')" "450"
baks=("$db".bak-*)
check_eq "one backup is kept" "${#baks[@]}" "1"
if [[ -f "${baks[0]}" ]]; then
    check_eq "backup holds the original" "$(sql "${baks[0]}" 'SELECT started_at_ms FROM smoking_quit_attempt')" "1000000000000"
else
    fail "backup file missing"
fi

# 4. Each run shifts once: a second run with 7 makes 14.
run --db "$db" 7
check_code "second shift exits 0" 0
check_eq "two runs shift 14 days" "$(sql "$db" 'SELECT epoch_day FROM smoking_event')" "$((11574 - 14))"

# 5. A database without the smoking tables fails and is left unchanged.
nodb="$scratch/t5.db"
sqlite3 "$nodb" "CREATE TABLE medications (id TEXT); INSERT INTO medications VALUES ('m');"
run --db "$nodb" 3
check_nonzero "no smoking tables fails"
check_out "no smoking tables is explained" "no smoking tables"
check_eq "database without smoking tables unchanged" "$(sql "$nodb" 'SELECT id FROM medications')" "m"

echo "smoking-shift-selftest: $passed passed, $failed failed"
[[ "$failed" -eq 0 ]]
