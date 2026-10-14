#!/usr/bin/env bash
# PreToolUse hook for Edit|Write|MultiEdit|Read|Grep: keeps agents away from what only the owner
# touches, or what a tool generates. Grep is judged like Read, by its `path`: a secret file blocks,
# a directory passes.
#   - any *.local.xcconfig (App/Secrets.local.xcconfig holds the machine's keys): blocked for
#     every tool, reads included — a secret read into a session is a secret leaked.
#   - Salus.xcodeproj/project.pbxproj: blocked for writes — `xcodegen generate` writes it from
#     project.yml. Reads are fine.
#   - Packages/SalusDatabase/Tests/**/RoomSchemas/*.json: blocked for writes — they are Android's
#     Room schemas, copied with `cp`, and an applied version is history.
#
# Reads the hook JSON on stdin; exit 2 with one reason line on stderr blocks the call. A relative
# path is taken from the repository root and `..` is resolved before judging; APFS ignores case,
# so the path is compared lower-cased. The path is judged only when it lies in this repository or
# one of its worktrees (see lib.sh); any other path is none of this hook's business. Input it
# cannot parse is allowed with a warning: a broken hook must not wedge the session.
set -euo pipefail

# shellcheck source=lib.sh
. "$(dirname "$0")/lib.sh"

PROJECT=salus.xcodeproj/project.pbxproj
ROOM_TESTS=packages/salusdatabase/tests

allow_with_warning() {
  echo "guard-files: warning: $1 — allowing the call unchecked" >&2
  exit 0
}

block() {
  echo "guard-files: $1" >&2
  exit 2
}

if ! command -v jq >/dev/null 2>&1; then allow_with_warning "jq is not installed"; fi
input="$(cat)"
if ! parsed="$(printf '%s' "$input" | jq -r '[.tool_name // "", .tool_input.file_path // .tool_input.path // .tool_input.notebook_path // ""] | join("\u0001")' 2>/dev/null)"; then
  allow_with_warning "the hook input is not the expected JSON"
fi
tool="${parsed%%$'\001'*}"
path="${parsed#*$'\001'}"
if [ -z "$path" ]; then exit 0; fi
if ! top="$(own_top)" || [ -z "$top" ]; then allow_with_warning "no repository root found"; fi

case "$path" in
  /*) abs="$(normalise "$path")" ;;
  *) abs="$(normalise "$top/$path")" ;;
esac
if ! same_repo "$abs"; then exit 0; fi
# The path is in this repository: failing to place it must never let it through.
if ! rel="$(repo_rel "$abs")" || [ -z "$rel" ]; then block "cannot place $path in its work tree — ask the owner"; fi
rel_lc="$(printf '%s' "$rel" | LC_ALL=C tr 'A-Z' 'a-z')"
name="${rel_lc##*/}"

case "$name" in
  *.local.xcconfig)
    block "$rel is machine-local secret config — never read or write it; ask the owner, they handle it" ;;
esac
if [ "$tool" = Read ] || [ "$tool" = Grep ]; then exit 0; fi

if [ "$rel_lc" = "$PROJECT" ]; then
  block "$rel is generated — edit project.yml and run xcodegen generate instead of writing it"
fi

# Packages/SalusDatabase/Tests/**/RoomSchemas/*.json — directly inside a RoomSchemas directory.
case "$rel_lc" in
  "$ROOM_TESTS"/*.json)
    dir="${rel_lc%/*}"
    if [ "${dir##*/}" = roomschemas ]; then
      block "$rel is a Room schema copied from Android — never write it; copy it with cp when Android's schema changes"
    fi ;;
esac
exit 0
