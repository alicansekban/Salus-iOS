# Smoking cessation — testing without waiting (iOS simulator)

Everything in the smoking feature is measured from stored instants: the quit start, the last slip
and the cravings. To see "30 days smoke-free" or a milestone notification you do not wait a month;
you seed a believable history and then move it back in time. Both steps are plain SQLite over the
schema-v5 `smoking_*` tables, so iOS and Android run the same two Python scripts from the Android
checkout. The dataset and the shift rules are specified once, in
`salus-android/docs/testing/smoking-testing.md`; this note covers the iOS wrappers.

Development builds on the simulator only. Preconditions: the app is installed, onboarding is
completed, and the app has been launched once on a build that includes smoking (the tables exist
from schema v5; on an older database the seeder skips the smoking rows and the shifter refuses).
`../salus-android` must be checked out on `feature/m17-smoking-cessation` or later
(`SALUS_ANDROID_DIR=<path>` overrides the location for the shift wrapper, `SEED_SCRIPT=<path>` the
seeder for the seed wrapper).

## 1. Seed the QUIT scenario

```
scripts/dev/seed-store-demo.sh [--lang tr|en]
```

This replaces all health data of the profile with the "Ayşe" store dataset, which includes a
smoking history: a QUIT plan (15 cigarettes a day, TRY), two price periods, a past attempt that
ended in a restart, a 42-day active attempt with one slip 17 days ago, and about 60 resisted
cravings. Use a demo simulator. No savings goal is seeded; create one in the app.

## 2. Move the history back N days

```
scripts/dev/smoking-shift.sh <days>
```

Run after the seed. It terminates the app, keeps a timestamped `salus.db.bak-<time>` next to the
database, subtracts `N` days from every smoking timestamp and day column (nothing else changes),
checks integrity and relaunches the app.

- **Each run shifts once.** Two runs with 7 shift 14 days; to start over, run the seed again (it
  re-anchors to "now").
- **Whole days only.** The time of day of every event is kept.
- `<days>` must be a positive whole number; a database without the smoking tables fails with a
  message and is left unchanged.
- `--db <path>` shifts a SQLite file instead of the simulator's database and never touches the
  simulator: use it for dry runs on a scratch copy.

## 3. Self-test

```
bash scripts/dev/smoking-shift-selftest.sh
```

Builds scratch databases from the committed Room v5 schema export (read with `git show` from the
Android branch) and runs the wrapper with `--db` against them: argument errors, backup, one-shot
shift, a second run, and a database without the smoking tables. It needs no simulator.
