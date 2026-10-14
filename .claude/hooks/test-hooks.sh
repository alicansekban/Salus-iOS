#!/usr/bin/env bash
# Feeds each PreToolUse hook sample JSON on stdin and checks its verdict: exit 2 with exactly one
# reason line on stderr blocks the call, exit 0 with a silent stderr allows it. Stops at the first
# failure, printing the hook's stderr.
#
# The hooks find their repository from their own location, never from $CLAUDE_PROJECT_DIR (spec
# D8), so the cases that need another repository copy the hooks into a scratch repository and run
# the copies there.
#
# usage: bash .claude/hooks/test-hooks.sh   (from any directory)
#        SALUS_ANDROID_DIR=<android checkout> bash .claude/hooks/test-hooks.sh
#          (where the byte-identity check finds the Android hooks; default ../salus-android)
set -euo pipefail

hooks="$(cd "$(dirname "$0")" && pwd)"
root="$(git -C "$hooks" rev-parse --show-toplevel)"
scratch="$(mktemp -d)"
trap 'rm -rf "$scratch"' EXIT

# The hooks ignore $CLAUDE_PROJECT_DIR; a few cases set it to a wrong value to prove that.
unset CLAUDE_PROJECT_DIR

err=""
code=0
passed=0
# The directory the hooks run from: this repository's, or a scratch repository's copy.
HDIR="$hooks"

# git with a throwaway identity, no signing and no hooks, so the machine's config does not matter
git_t() {
  git -c user.name=t -c user.email=t@t -c commit.gpgsign=false -c core.hooksPath=/dev/null "$@"
}

bash_json() { jq -cn --arg c "$1" '{tool_name: "Bash", tool_input: {command: $c}}'; }
file_json() { jq -cn --arg p "$1" '{tool_name: "Edit", tool_input: {file_path: $p}}'; }
tool_json() { # tool path — Grep names its target `path`, the file tools `file_path`
  if [ "$1" = Grep ]; then
    jq -cn --arg p "$2" '{tool_name: "Grep", tool_input: {pattern: "x", path: $p}}'
  else
    jq -cn --arg t "$1" --arg p "$2" '{tool_name: $t, tool_input: {file_path: $p}}'
  fi
}

# sq TEXT — TEXT as one single-quoted shell word.
sq() { printf "'%s'" "$(printf '%s' "$1" | sed "s/'/'\\\\''/g")"; }

# nest N SCRIPT — SCRIPT wrapped in N levels of `sh -c '…'`.
nest() {
  local k=0 s="$2"
  while [ "$k" -lt "$1" ]; do
    s="sh -c $(sq "$s")"
    k=$((k + 1))
  done
  printf '%s' "$s"
}

# The repository root in another case: APFS ignores case, so it is the same directory.
lower() { printf '%s' "$1" | LC_ALL=C tr 'A-Z' 'a-z'; }
upper() { printf '%s' "$1" | LC_ALL=C tr 'a-z' 'A-Z'; }

# run INPUT HOOK [ARGS…] — runs the hook directly (the way Claude Code does, so the executable bit
# counts), keeping only its stderr in $err and its exit status in $code.
run() {
  local input="$1" hook="$2"
  shift 2
  set +e
  err="$(printf '%s' "$input" | "$HDIR/$hook" "$@" 2>&1 >/dev/null)"
  code=$?
  set -e
}

fail() {
  echo "FAIL $1: $2"
  printf '%s\n' "$err" | sed 's/^/    /'
  exit 1
}

ok() {
  passed=$((passed + 1))
  echo "ok   $1"
}

lines() { # the number of lines in $err
  if [ -z "$err" ]; then echo 0; else printf '%s\n' "$err" | wc -l | tr -d ' '; fi
}

expect_block() { # case
  if [ "$code" -ne 2 ]; then fail "$1" "exit $code, expected 2"; fi
  if [ "$(lines)" -ne 1 ]; then fail "$1" "$(lines) stderr lines, expected one reason line"; fi
}

expect_allow() { # case
  if [ "$code" -ne 0 ]; then fail "$1" "exit $code, expected 0"; fi
  if [ -n "$err" ]; then fail "$1" "unexpected stderr on an allowed call"; fi
}

expect_allow_warned() { # case — unparseable input is allowed, with a warning
  if [ "$code" -ne 0 ]; then fail "$1" "exit $code, expected 0"; fi
  case "$err" in *warning*) ;; *) fail "$1" "no warning on stderr" ;; esac
}

# --- guard-bash.sh ---------------------------------------------------------------------------------

bash_blocks() { # command
  run "$(bash_json "$1")" guard-bash.sh
  expect_block "guard-bash blocks: $1"
  case "$err" in
    *"— ask the owner; they run it") ;;
    *) fail "guard-bash blocks: $1" "reason does not end with '— ask the owner; they run it'" ;;
  esac
  ok "guard-bash blocks: $1"
}

bash_allows() { # command
  run "$(bash_json "$1")" guard-bash.sh
  expect_allow "guard-bash allows: $1"
  ok "guard-bash allows: $1"
}

bash_blocks 'git push --force origin x'
bash_blocks 'git push -f'
bash_blocks 'git push --force-with-lease origin x'
bash_blocks 'git -C ../wt-a push -uf origin x'
bash_blocks 'git push --force-with-lease=main origin main'
bash_blocks 'git status && git push --force-with-lease=main origin main'
# A `+` refspec force-updates its ref; --mirror force-updates and deletes remote refs.
bash_blocks 'git push origin +feature/x'
bash_blocks 'git push origin +HEAD:main'
bash_blocks 'git push --mirror'
bash_blocks 'git push --mirror origin'
# Only a fast-forward merge reaches main; any other shape is the owner's.
bash_blocks 'git merge feature/x'
bash_blocks 'git merge --no-ff feature/x'
bash_blocks 'git merge --squash x'
bash_blocks 'git merge --ff-only --no-ff x'
bash_blocks 'git -C ../wt-a merge x'
bash_blocks 'git pull'
bash_blocks 'git pull origin main'
bash_blocks 'git pull --no-rebase'
bash_blocks 'git pull --no-ff'
bash_blocks 'git pull --ff-only --no-ff'
bash_blocks 'git pull --rebase=false'
bash_blocks 'git add -f keystore.properties'
bash_blocks 'git add --force x'
bash_blocks 'git add -nf x'
# The same rules through the shapes a command really arrives in.
bash_blocks 'echo "$(git push -f)"'
bash_blocks "bash -c 'git merge x'"
bash_blocks "eval 'git pull'"
bash_blocks $'bash <<\'EOF\'\ngit merge x\nEOF'
# APFS ignores case, so `GIT` and `Bash` run git and bash: program names match in any case.
bash_blocks 'GIT push --force origin x'
bash_blocks 'Git push -f'
bash_blocks '/usr/bin/GIT merge x'
bash_blocks "BASH -c 'git merge x'"
bash_blocks "Sh -c 'git pull'"
bash_blocks "EVAL 'git pull'"
# Nested scripts are checked down to MAX_DEPTH (4); anything deeper cannot be checked, so it is
# blocked whatever it holds.
bash_blocks "$(nest 4 'git push -f')"
bash_allows "$(nest 4 'git status')"
bash_blocks "$(nest 5 'git status')"
bash_blocks "$(nest 6 'git push -f')"
case "$err" in *"nested too deep to check"*) ;; *) fail "six sh -c levels" "the reason does not say 'nested too deep to check'" ;; esac
ok "six sh -c levels: the reason says nested too deep to check"

bash_allows 'git push origin feature/x'
# Only a leading `+` forces; a branch name may hold one.
bash_allows 'git push origin feature/x+y'
bash_allows 'git status'
bash_allows 'git merge --ff-only feature/x'
bash_allows 'git merge --ff-only -m note feature/x'
bash_allows 'git merge --abort'
bash_allows 'git merge --continue'
bash_allows 'git merge --quit'
bash_allows 'git merge-base main HEAD'
bash_allows 'git pull --ff-only'
bash_allows 'git pull --rebase'
bash_allows 'git pull --rebase=merges origin main'
bash_allows 'git pull origin main --ff-only'
bash_allows 'git rebase main'
bash_allows 'git add docs/a.md'
bash_allows 'git add .'
bash_allows 'git add -- -f'
# Quoted text is an argument, not a command: a commit message may name what the hook blocks.
bash_allows 'git commit -m "never git push --force or git merge x"'
bash_allows 'git commit -m "docs: git pull and git add -f stay the owner'"'"'s call"'
bash_allows $'git commit -F - <<\'EOF\'\ndocs: guard-bash blocks git merge x\nEOF'
bash_allows $'cat >> ledger.md <<\'EOF\'\n- guard-bash blocks git push --force\nEOF'
# Claude Code's commit shape: the heredoc inside "$(…)" is data, even with an odd number of `"`.
bash_allows $'git commit -m "$(cat <<\'EOF\'\ndocs: the 27" monitor note\n\nnever git push --force here, never git merge x\nEOF\n)"'

run 'not json' guard-bash.sh
expect_allow_warned "guard-bash allows unparseable input"
ok "guard-bash allows unparseable input"

# A tokenizer that fails yields no words, which would read as "nothing to block": the call is
# allowed but never silently. The stand-in awk fails the way a broken tokenizer would.
mkdir -p "$scratch/broken-awk"
printf '#!/bin/sh\nexit 1\n' > "$scratch/broken-awk/awk"
chmod +x "$scratch/broken-awk/awk"
input="$(bash_json 'git push -f')"
saved_path="$PATH"
PATH="$scratch/broken-awk:$PATH"
run "$input" guard-bash.sh
PATH="$saved_path"
expect_allow_warned "guard-bash warns when its tokenizer fails"
case "$err" in *tokenizer*) ;; *) fail "guard-bash warns when its tokenizer fails" "the warning does not name the tokenizer" ;; esac
ok "guard-bash warns when its tokenizer fails"

# --- guard-files.sh --------------------------------------------------------------------------------

# files_blocks TOOL PATH / files_allows TOOL PATH — judged by the hooks in $HDIR.
files_blocks() {
  run "$(tool_json "$1" "$2")" guard-files.sh
  expect_block "guard-files blocks $1: $2"
  ok "guard-files blocks $1: $2"
}

files_allows() {
  run "$(tool_json "$1" "$2")" guard-files.sh
  expect_allow "guard-files allows $1: $2"
  ok "guard-files allows $1: $2"
}

# The machine-local secrets file (and any *.local.xcconfig) is blocked for every tool, reads
# included; APFS ignores case, so every spelling counts.
for tool in Read Edit Write MultiEdit; do
  files_blocks $tool "$root/App/Secrets.local.xcconfig"
done
files_blocks Read 'App/Secrets.local.xcconfig'
files_blocks Edit 'x/Other.local.xcconfig'
files_blocks Read "$root/x/Other.local.xcconfig"
files_blocks Read 'App/SECRETS.LOCAL.XCCONFIG'
files_blocks Write 'x/other.Local.XCConfig'
files_blocks Read "$root/app/Secrets.local.xcconfig"
files_blocks Read 'docs/../App/Secrets.local.xcconfig'
files_blocks Read "$root/docs/../App/Secrets.local.xcconfig"
files_blocks Edit "$root/Packages/../App/Secrets.local.xcconfig"
# The committed template next to it holds no secret.
files_allows Read 'App/Secrets.xcconfig'
files_allows Edit "$root/App/Secrets.xcconfig"
files_allows Read "$root/App/Secrets.local.xcconfig.sample"

# The generated project is written by `xcodegen generate` only; reads are fine.
roomdir=Packages/SalusDatabase/Tests/SalusDatabaseTests/Resources/RoomSchemas
for tool in Edit Write MultiEdit; do
  files_blocks $tool "$root/Salus.xcodeproj/project.pbxproj"
done
files_blocks Edit 'Salus.xcodeproj/project.pbxproj'
files_blocks Edit 'salus.XCODEPROJ/PROJECT.PBXPROJ'
files_blocks Write "$root/SALUS.xcodeproj/Project.pbxproj"
files_blocks Edit 'docs/../Salus.xcodeproj/project.pbxproj'
files_blocks Write "$root/Salus.xcodeproj/../Salus.xcodeproj/project.pbxproj"
files_allows Read "$root/Salus.xcodeproj/project.pbxproj"
files_allows Read 'Salus.xcodeproj/project.pbxproj'
files_allows Edit 'project.yml'
files_allows Edit "$root/project.yml"
# The copied Room schemas are written with `cp` from Android, never by an agent.
for tool in Edit Write MultiEdit; do
  files_blocks $tool "$root/$roomdir/4.json"
done
files_blocks Edit "$roomdir/4.json"
files_blocks Write "$roomdir/1.json"
files_blocks Edit "packages/salusdatabase/tests/salusdatabasetests/resources/roomschemas/4.JSON"
files_blocks Edit "docs/../$roomdir/4.json"
files_blocks Write "$root/Packages/SalusDatabase/Tests/OtherTests/RoomSchemas/1.json"
files_allows Read "$root/$roomdir/1.json"
files_allows Read "$roomdir/4.json"
files_allows Edit "$roomdir/README.md"
files_allows Edit "$root/Packages/SalusDatabase/Tests/SalusDatabaseTests/MigrationTests.swift"
files_allows Edit "$root/Packages/SalusDatabase/Sources/SalusDatabase/RoomSchemas/4.json"
files_allows Edit 'App/x.swift'
files_allows Edit "$root/App/RootView.swift"
files_allows Read '/tmp/x.md'
# Grep reads files too, by its `path`: judged like Read — a secret file blocks, a directory or a
# readable file passes. A notebook path is judged like a file path.
files_blocks Grep "$root/App/Secrets.local.xcconfig"
files_blocks Grep 'App/Secrets.local.xcconfig'
files_blocks Grep "$root/x/OTHER.LOCAL.XCCONFIG"
files_blocks Grep 'docs/../App/Secrets.local.xcconfig'
files_allows Grep "$root"
files_allows Grep 'App'
files_allows Grep "$root/Salus.xcodeproj/project.pbxproj"
files_allows Grep "$root/$roomdir/4.json"
run "$(jq -cn --arg p "$root/App/Secrets.local.xcconfig" '{tool_name: "NotebookEdit", tool_input: {notebook_path: $p}}')" guard-files.sh
expect_block "guard-files blocks NotebookEdit: notebook_path Secrets.local.xcconfig"
ok "guard-files blocks NotebookEdit: notebook_path Secrets.local.xcconfig"
# APFS ignores case in the whole path, the repository root included: the root spelled lower- or
# upper-case is the same directory and is judged the same.
if [ -d "$(lower "$root")" ] && [ -d "$(upper "$root")" ]; then
  for spelled in "$(lower "$root")" "$(upper "$root")"; do
    for tool in Read Grep Edit; do
      files_blocks $tool "$spelled/App/Secrets.local.xcconfig"
      files_blocks $tool "$spelled/app/secrets.LOCAL.xcconfig"
      files_blocks $tool "$spelled/x/Other.local.xcconfig"
    done
    files_blocks Edit "$spelled/Salus.xcodeproj/project.pbxproj"
    files_blocks Write "$spelled/$roomdir/4.json"
    files_allows Read "$spelled/Salus.xcodeproj/project.pbxproj"
    files_allows Edit "$spelled/App/x.swift"
  done
else
  ok "guard-files: root in another case — skipped (case-sensitive file system)"
fi
# The hooks ignore $CLAUDE_PROJECT_DIR: a wrong value changes nothing.
export CLAUDE_PROJECT_DIR="$scratch"
files_blocks Read "$root/App/Secrets.local.xcconfig"
files_allows Edit "$root/App/x.swift"
unset CLAUDE_PROJECT_DIR

# A scratch repository holds the hooks (committed, so its worktrees carry them too), the project,
# a copied Room schema and the secrets file's template.
mkrepo() { # dir
  git_t init -q -b main "$1"
  mkdir -p "$1/.claude/hooks" "$1/$roomdir" "$1/App" "$1/docs" "$1/Salus.xcodeproj"
  cp "$hooks/lib.sh" "$hooks/guard-files.sh" "$hooks/write-scope.sh" "$1/.claude/hooks/"
  echo '{}' > "$1/$roomdir/4.json"
  echo 'a' > "$1/App/x.swift"
  echo 'p' > "$1/Salus.xcodeproj/project.pbxproj"
  echo 'name: Salus' > "$1/project.yml"
  git_t -C "$1" add -A
  git_t -C "$1" commit -qm base
}

repo="$scratch/repo"
mkrepo "$repo"
git_t -C "$repo" checkout -q -b feature
echo 'b' > "$repo/App/y.swift"
git_t -C "$repo" add -A
git_t -C "$repo" commit -qm 'new file'
HDIR="$repo/.claude/hooks"

files_blocks Read "$repo/App/Secrets.local.xcconfig"
files_blocks Edit "$repo/Salus.xcodeproj/project.pbxproj"
files_blocks Write "$repo/$roomdir/4.json"
files_blocks MultiEdit "$roomdir/4.json"
files_blocks Edit "docs/../Salus.xcodeproj/project.pbxproj"
files_allows Read "$repo/Salus.xcodeproj/project.pbxproj"
files_allows Edit "$repo/project.yml"
files_allows Edit "$repo/App/x.swift"
files_allows Edit "$repo/App/y.swift"
# The scratch root spelled in another case is judged the same.
if [ -d "$(lower "$repo")" ] && [ -d "$(upper "$repo")" ]; then
  files_blocks Edit "$(lower "$repo")/Salus.xcodeproj/project.pbxproj"
  files_blocks Write "$(upper "$repo")/$roomdir/4.json"
  files_blocks Read "$(upper "$repo")/App/Secrets.local.xcconfig"
  files_allows Edit "$(lower "$repo")/App/x.swift"
fi
# Once a path is known to be in this repository, a failure to place it in its work tree blocks:
# the git dir itself is in no work tree.
files_blocks Read "$repo/.git/config"
case "$err" in *"cannot place"*) ;; *) fail "guard-files fails closed" "the reason does not say it cannot place the path" ;; esac
ok "guard-files: a path in the repository it cannot place is blocked"

# A scratch repository that is not the hooks' own is ignored: neither its secrets nor its project.
other="$scratch/other"
mkrepo "$other"
files_allows Read "$other/App/Secrets.local.xcconfig"
files_allows Edit "$other/Salus.xcodeproj/project.pbxproj"
files_allows Edit "$other/$roomdir/4.json"
# So is a path outside any repository.
mkdir -p "$scratch/loose"
files_allows Read "$scratch/loose/App/Secrets.local.xcconfig"
files_allows Edit "$scratch/loose/Salus.xcodeproj/project.pbxproj"
# A path whose directories do not exist yet is judged by its nearest existing ancestor.
files_blocks Write "$repo/new/dir/Other.local.xcconfig"
files_allows Write "$other/new/dir/Other.local.xcconfig"

# A worktree of the scratch repo is judged like its main checkout, whichever copy of the hooks runs.
git_t -C "$repo" worktree add -q -b wt-b "$scratch/wt" feature
files_blocks Read "$scratch/wt/App/Secrets.local.xcconfig"
files_blocks Edit "$scratch/wt/Salus.xcodeproj/project.pbxproj"
files_blocks Edit "$scratch/wt/$roomdir/4.json"
files_blocks Edit "$scratch/wt/salus.xcodeproj/Project.pbxproj"
files_allows Read "$scratch/wt/Salus.xcodeproj/project.pbxproj"
files_allows Edit "$scratch/wt/project.yml"
files_allows Edit "$scratch/wt/App/x.swift"
files_allows Read "$other/App/Secrets.local.xcconfig"
HDIR="$scratch/wt/.claude/hooks"
files_blocks Read "$repo/App/Secrets.local.xcconfig"
files_blocks Edit "$repo/Salus.xcodeproj/project.pbxproj"
files_blocks Read "$scratch/wt/x/Other.local.xcconfig"
files_allows Edit "$repo/App/x.swift"
files_allows Read "$other/App/Secrets.local.xcconfig"

HDIR="$hooks"
run 'not json' guard-files.sh
expect_allow_warned "guard-files allows unparseable input"
ok "guard-files allows unparseable input"

# --- write-scope.sh --------------------------------------------------------------------------------

# Every argument but the last is a prefix; the last is the file path.
scope_blocks() { # prefix… file_path
  local path="${@: -1}"
  run "$(file_json "$path")" write-scope.sh "${@:1:$#-1}"
  expect_block "write-scope ${*:1:$#-1} blocks: $path"
  ok "write-scope ${*:1:$#-1} blocks: $path"
}

scope_allows() { # prefix… file_path
  local path="${@: -1}"
  run "$(file_json "$path")" write-scope.sh "${@:1:$#-1}"
  expect_allow "write-scope ${*:1:$#-1} allows: $path"
  ok "write-scope ${*:1:$#-1} allows: $path"
}

scope_blocks docs/ "$root/App/x.swift"
scope_allows docs/ "$root/docs/a.md"
scope_allows docs/ 'docs/a.md'
# `..` is resolved before judging, relative or absolute.
scope_blocks docs/ 'docs/../App/x.swift'
scope_blocks docs/ "$root/docs/../App/x.swift"
scope_blocks docs/ '/tmp/x.md'
# A sibling checkout whose name starts with the root's (../wt-harness-ios-b) is outside the root.
scope_blocks docs/ "$root-b/docs/a.md"
# The root spelled in another case is the same directory (APFS ignores case).
if [ -d "$(lower "$root")" ] && [ -d "$(upper "$root")" ]; then
  scope_allows docs/ "$(lower "$root")/docs/a.md"
  scope_allows docs/ "$(upper "$root")/docs/a.md"
  scope_blocks docs/ "$(lower "$root")/App/x.swift"
  scope_blocks docs/ "$(upper "$root")/App/x.swift"
fi
# A prefix is a directory: `docs` means `docs/`, never `docsx/`.
scope_allows docs 'docs/a.md'
scope_blocks docs 'docsx/a.md'
scope_allows docs/superpowers/plans/evidence/ "$root/docs/superpowers/plans/evidence/slice-8/a.png"
scope_blocks docs/superpowers/plans/evidence/ "$root/docs/superpowers/plans/STATUS-slice-8.md"
# Several prefixes: a path under any of them is allowed (the agents also write their report in the
# ignored plan workspace).
scope_allows docs/ .superpowers/sdd/ "$root/.superpowers/sdd/plan/task-8-report.md"
scope_allows docs/ .superpowers/sdd/ 'docs/a.md'
scope_allows docs/superpowers/plans/evidence/ .superpowers/sdd/ '.superpowers/sdd/plan/evidence-report.md'
scope_blocks docs/ .superpowers/sdd/ "$root/App/x.swift"
scope_blocks docs/superpowers/plans/evidence/ .superpowers/sdd/ 'docs/superpowers/STATUS.md'
scope_blocks docs/ .superpowers/sdd/ '.superpowers/sdd/../../App/x.swift'
scope_blocks docs/ .superpowers/sdd/ "$root/.superpowers/sdd/../x.md"

# $CLAUDE_PROJECT_DIR is ignored: the repository is the hooks' own.
export CLAUDE_PROJECT_DIR="$scratch"
scope_allows docs/ "$root/docs/a.md"
scope_blocks docs/ "$scratch/docs/a.md"
unset CLAUDE_PROJECT_DIR

# The prefix is relative to the top level of the path's own work tree: a worktree of this
# repository is judged by its own `docs/`, and any other repository or none at all is outside.
HDIR="$repo/.claude/hooks"
scope_allows docs/ "$repo/docs/a.md"
scope_allows docs/ "$scratch/wt/docs/a.md"
scope_blocks docs/ "$scratch/wt/App/x.swift"
scope_blocks docs/ "$scratch/wt/docs/../App/x.swift"
scope_allows docs/ .superpowers/sdd/ "$scratch/wt/.superpowers/sdd/plan/r.md"
scope_blocks docs/ "$other/docs/a.md"
scope_blocks docs/ "$scratch/loose/docs/a.md"
scope_blocks docs/ "$scratch/loose/new/docs/a.md"
HDIR="$scratch/wt/.claude/hooks"
scope_allows docs/ "$repo/docs/a.md"
scope_blocks docs/ "$repo/App/x.swift"
HDIR="$hooks"

run 'not json' write-scope.sh docs/
expect_allow_warned "write-scope allows unparseable input"
ok "write-scope allows unparseable input"

# A missing prefix is a configuration error: reported, never a block (a broken hook must not wedge
# the session).
run "$(file_json docs/a.md)" write-scope.sh
if [ "$code" -eq 0 ] || [ "$code" -eq 2 ]; then fail "write-scope without a prefix" "exit $code, expected a usage error"; fi
if [ "$code" -ne 1 ]; then fail "write-scope without a prefix" "exit $code, expected 1"; fi
ok "write-scope without a prefix"
# An empty prefix among several would admit the whole root: the same usage error.
run "$(file_json App/x.swift)" write-scope.sh docs/ ''
if [ "$code" -ne 1 ]; then fail "write-scope with an empty prefix" "exit $code, expected 1"; fi
ok "write-scope with an empty prefix"

# --- lib.sh, sourced on its own ---------------------------------------------------------------------

# Each helper locates the path itself: none may depend on an earlier call in the same shell.
lib_rel="$(bash -c '. "$1/lib.sh"; repo_rel "$2"' _ "$hooks" "$root/App/x.swift")" || lib_rel="(failed)"
if [ "$lib_rel" != "App/x.swift" ]; then err="$lib_rel"; fail "lib.sh repo_rel standalone" "expected App/x.swift"; fi
ok "lib.sh: repo_rel without a prior same_repo"
lib_rel="$(bash -c '. "$1/lib.sh"; repo_rel "$2"' _ "$hooks" "$root/new/dir/Other.local.xcconfig")" || lib_rel="(failed)"
if [ "$lib_rel" != "new/dir/Other.local.xcconfig" ]; then err="$lib_rel"; fail "lib.sh repo_rel standalone, missing dirs" "expected new/dir/Other.local.xcconfig"; fi
ok "lib.sh: repo_rel for a path whose directories do not exist"
if ! bash -c '. "$1/lib.sh"; same_repo "$2"' _ "$hooks" "$root/App/x.swift"; then err=""; fail "lib.sh same_repo standalone" "own path not recognised"; fi
if bash -c '. "$1/lib.sh"; same_repo "$2"' _ "$hooks" "$scratch/loose/x"; then err=""; fail "lib.sh same_repo standalone" "foreign path recognised"; fi
ok "lib.sh: same_repo standalone"
lib_rel="$(bash -c '. "$1/lib.sh"; repo_rel "$2"' _ "$hooks" "$scratch/wt/docs/a.md")" || lib_rel="(failed)"
if [ "$lib_rel" != "docs/a.md" ]; then err="$lib_rel"; fail "lib.sh repo_rel in a worktree" "expected docs/a.md"; fi
ok "lib.sh: repo_rel in a worktree is relative to the worktree"
if [ -d "$(lower "$root")" ]; then
  lib_rel="$(bash -c '. "$1/lib.sh"; repo_rel "$2"' _ "$hooks" "$(lower "$root")/App/X.swift")" || lib_rel="(failed)"
  if [ "$lib_rel" != "App/X.swift" ]; then err="$lib_rel"; fail "lib.sh repo_rel, root in lower case" "expected App/X.swift"; fi
  ok "lib.sh: repo_rel with the root in lower case keeps the rest as typed"
fi

# --- settings.json ----------------------------------------------------------------------------------

# guard-files.sh must see every tool that reads or writes a file by path, Grep included.
matcher="$(jq -r '.hooks.PreToolUse[] | select(any(.hooks[]; .command | test("guard-files"))) | .matcher' "$root/.claude/settings.json")"
for tool in Edit Write MultiEdit Read Grep; do
  case "|$matcher|" in
    *"|$tool|"*) ;;
    *) err="$matcher"; fail "settings.json: guard-files matcher" "does not name $tool" ;;
  esac
done
ok "settings.json: guard-files sees Edit, Write, MultiEdit, Read and Grep"

# --- the files themselves ---------------------------------------------------------------------------

for hook in lib.sh guard-bash.sh guard-files.sh write-scope.sh test-hooks.sh; do
  err="$(bash -n "$hooks/$hook" 2>&1)" || fail "$hook" "bash -n failed"
  if [ ! -x "$hooks/$hook" ]; then err=""; fail "$hook" "not executable"; fi
  ok "$hook: bash -n, executable"
done

# --- the files shared with Android ------------------------------------------------------------------

# guard-bash.sh, write-scope.sh and lib.sh are byte-identical in both repositories (plan ruling 2):
# a fix lands on Android first and is copied here. The check needs the Android checkout: its
# location is $SALUS_ANDROID_DIR when set, else ../salus-android next to this repository; a missing
# directory or file (CI, a checkout without the hooks yet) skips the file, visibly.
android="${SALUS_ANDROID_DIR:-$root/../salus-android}"
for shared in lib.sh guard-bash.sh write-scope.sh; do
  theirs="$android/.claude/hooks/$shared"
  if [ ! -f "$theirs" ]; then
    ok "$shared: identical to Android's — skipped (no android checkout)"
  elif cmp -s "$hooks/$shared" "$theirs"; then
    ok "$shared: identical to Android's"
  else
    err="$theirs"
    fail "$shared: identical to Android's" "differs from the Android copy — land the change on Android first, then cp it here"
  fi
done

echo "test-hooks: $passed passed"
