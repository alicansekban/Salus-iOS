# Shared helpers for guard-files.sh and write-scope.sh — sourced, never run.
#
# A hook finds its repository from its own file location, never from $CLAUDE_PROJECT_DIR: the
# session that runs it may be rooted anywhere (a parent folder, another worktree). A path is
# judged only when its nearest existing ancestor directory belongs to a git work tree whose common
# git dir is the hook's own, i.e. this repository or one of its worktrees (`git worktree add
# ../wt-<x>`), which are guarded exactly like the main checkout.
#
# bash 3.2 (macOS): no associative arrays, no mapfile, no ${var,,}.

lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"

# Lexical only: the file may not exist yet, so symlinks cannot be resolved.
normalise() { # absolute path
  local out="" seg IFS=/
  set -f
  for seg in $1; do
    case "$seg" in
      '' | .) ;;
      ..) out="${out%/*}" ;;
      *) out="$out/$seg" ;;
    esac
  done
  set +f
  printf '%s\n' "${out:-/}"
}

# The git dir shared by this repository and its worktrees, as an absolute path.
own_common_dir() {
  git -C "$lib_dir" rev-parse --path-format=absolute --git-common-dir 2>/dev/null
}

# The top level of the work tree the hooks live in: where a relative path starts.
own_top() {
  git -C "$lib_dir" rev-parse --show-toplevel 2>/dev/null
}

# locate ABS — sets LOC_DIR to the physical (symlinks resolved) nearest existing ancestor directory
# of ABS, and LOC_PATH to ABS with that ancestor resolved and the missing rest appended.
locate() {
  local d="$1" rest=""
  while [ ! -d "$d" ]; do
    rest="/${d##*/}$rest"
    d="${d%/*}"
    if [ -z "$d" ]; then d=/; fi
  done
  LOC_DIR="$(cd "$d" && pwd -P)"
  LOC_PATH="${LOC_DIR%/}$rest"
}

# same_repo ABS — succeeds when ABS lies in this repository or one of its worktrees.
same_repo() {
  local common own
  locate "$1"
  if ! common="$(git -C "$LOC_DIR" rev-parse --path-format=absolute --git-common-dir 2>/dev/null)"; then return 1; fi
  if ! own="$(own_common_dir)"; then return 1; fi
  [ -n "$common" ] && [ "$common" = "$own" ]
}

# repo_top ABS — prints the top level of the work tree that holds ABS (the worktree's own, for a
# path in a worktree); fails when ABS is in no work tree.
repo_top() {
  locate "$1"
  git -C "$LOC_DIR" rev-parse --show-toplevel 2>/dev/null
}

# repo_rel ABS — prints ABS relative to repo_top; fails when ABS is in no work tree. Locates ABS
# itself, so it needs no earlier call.
repo_rel() {
  local top
  locate "$1"
  if ! top="$(git -C "$LOC_DIR" rev-parse --show-toplevel 2>/dev/null)" || [ -z "$top" ]; then return 1; fi
  case "$LOC_PATH" in
    "$top"/*) printf '%s\n' "${LOC_PATH#"$top"/}" ;;
    *) return 1 ;;
  esac
}
