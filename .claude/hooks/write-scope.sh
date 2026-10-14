#!/usr/bin/env bash
# PreToolUse hook for an agent's Edit|Write: the agent may write only under the given directories
# of the repository. Used from agent frontmatter, e.g.
#   "$CLAUDE_PROJECT_DIR"/.claude/hooks/write-scope.sh docs/ .superpowers/sdd/
#
# usage: write-scope.sh <prefix> [<prefix>…]   — each <prefix> is relative to the git top level of
#                                                the path being written (`docs/`,
#                                                `docs/superpowers/plans/evidence/`,
#                                                `.superpowers/sdd/`); a path under any is allowed
#
# Reads the hook JSON on stdin; exit 2 with one reason line on stderr blocks the call. The path must
# lie in this repository or one of its worktrees (see lib.sh) — a worktree is judged by its own
# top level; a path in another repository or in none is outside every prefix. A relative path is
# taken from the repository root, and `..` is resolved before judging, so `docs/../app/x.kt` is
# outside `docs/`. Input it cannot parse is allowed with a warning, and a missing or empty prefix is
# a usage error (exit 1, which Claude Code shows but does not block on): a broken hook must not
# wedge the session.
set -euo pipefail

# shellcheck source=lib.sh
. "$(dirname "$0")/lib.sh"

allow_with_warning() {
  echo "write-scope: warning: $1 — allowing the call unchecked" >&2
  exit 0
}

usage() {
  echo "write-scope: usage: write-scope.sh <prefix relative to the repository root> [<prefix>…]" >&2
  exit 1
}

# An empty prefix would admit the whole root, so it is a usage error rather than an allow.
if [ $# -eq 0 ]; then usage; fi
for p in "$@"; do
  if [ -z "$p" ]; then usage; fi
done

# A prefix names a directory: `docs` must not admit `docsx/`.
as_dir() { # prefix
  local p="${1#./}"
  printf '%s/\n' "${p%/}"
}

if ! command -v jq >/dev/null 2>&1; then allow_with_warning "jq is not installed"; fi
input="$(cat)"
if ! path="$(printf '%s' "$input" | jq -r '.tool_input.file_path // .tool_input.notebook_path // empty' 2>/dev/null)"; then
  allow_with_warning "the hook input is not the expected JSON"
fi
if [ -z "$path" ]; then exit 0; fi
if ! top="$(own_top)" || [ -z "$top" ]; then allow_with_warning "no repository root found"; fi

scope=""
for p in "$@"; do
  scope="${scope:+$scope or }$(as_dir "$p")"
done

case "$path" in
  /*) abs="$(normalise "$path")" ;;
  *) abs="$(normalise "$top/$path")" ;;
esac
if same_repo "$abs" && rel="$(repo_rel "$abs")"; then
  for p in "$@"; do
    prefix="$(as_dir "$p")"
    case "$rel" in
      "$prefix"*) exit 0 ;;
    esac
  done
fi
echo "write-scope: $path is outside $scope — this agent writes only under $scope of this repository" >&2
exit 2
