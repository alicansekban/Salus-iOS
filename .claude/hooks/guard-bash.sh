#!/usr/bin/env bash
# PreToolUse hook for Bash: stops the git commands only the owner runs — a force push, a merge that
# is not a fast-forward, a pull that merges, `git add --force` (which would stage ignored secrets).
#
# Reads the hook JSON on stdin; exit 2 with one reason line on stderr blocks the call. The command
# is split into words the way the shell would (quotes removed, `&&` `;` `|` newlines as
# separators), so quoted text and heredoc bodies — a commit message, a file being written — never
# count as commands. A command substitution `$(…)`, quoted or not, is executed code and is checked
# as a script of its own, as are a shell's `-c` script, a heredoc a shell reads, and `eval`.
# Input it cannot parse is allowed with a warning: a broken hook must not wedge the session.
set -euo pipefail

# Nested scripts (`sh -c`, `$(…)`) are checked too, down to this depth; a script nested deeper
# cannot be checked, so it is blocked rather than let through.
MAX_DEPTH=4

block() {
  echo "guard-bash: $1 — ask the owner; they run it" >&2
  exit 2
}

allow_with_warning() {
  echo "guard-bash: warning: $1 — allowing the call unchecked" >&2
  exit 0
}

# Word splitter, run with LC_ALL=C so it is byte-exact on any input. Prints one word per line,
# encoded so a word stays on one line: `\` as `\\`, newline as `\n`. The line `\;` ends a pipeline
# (and its last simple command), `\|` ends a simple command inside a pipeline. Two tagged words
# carry nested text: `\h` a heredoc or here-string body (data, unless a shell reads it),
# `\s` the script of a command substitution. Redirection targets and fd numbers are dropped so
# they never pass for arguments.
# Read with `read`, not `$(cat <<…)`: bash 3.2 mis-parses a heredoc inside `$(…)` whose text has
# unbalanced parentheses. `read -d ''` stops at end of input with status 1, hence `|| true`.
IFS= read -r -d '' tokenizer <<'AWK' || true
function add(ch) {
  if (ch == "\\") tok = tok "\\\\"
  else if (ch == "\n") tok = tok "\\n"
  else tok = tok ch
  have = 1
}
function flush() {
  if (have) {
    if (drop) drop = 0
    else if (herestring) { print "\\h" tok; herestring = 0 }
    else print tok
  }
  tok = ""; have = 0
}
function sep(mark) { flush(); drop = 0; herestring = 0; print mark }
function encoded(s,   out, k, ch) {
  out = ""
  for (k = 1; k <= length(s); k++) {
    ch = substr(s, k, 1)
    if (ch == "\\") out = out "\\\\"
    else if (ch == "\n") out = out "\\n"
    else out = out ch
  }
  return out
}
function next_char() { return substr(src, i + 1, 1) }
# From j (the second "<" of "<<"), reads a heredoc delimiter word into hd_delim / hd_strip and
# returns the position of its last character.
function read_delim(j) {
  hd_strip = 0; hd_delim = ""
  if (substr(src, j + 1, 1) == "-") { hd_strip = 1; j++ }
  while (substr(src, j + 1, 1) == " " || substr(src, j + 1, 1) == "\t") j++
  while (j < n && substr(src, j + 1, 1) !~ /[ \t\n;&|()<>]/) {
    j++
    if (substr(src, j, 1) !~ /["'\\]/) hd_delim = hd_delim substr(src, j, 1)
  }
  return j
}
# From the newline at j, reads a heredoc body up to its delimiter line into `body`; returns the
# position of the newline that ends the delimiter line.
function read_body(j, d, s,   start, e, line, cmp) {
  body = ""
  while (j < n) {
    start = j + 1
    e = index(substr(src, start), "\n")
    if (e == 0) { line = substr(src, start); j = n } else { line = substr(src, start, e - 1); j = start + e - 1 }
    cmp = line
    if (s) sub(/^\t+/, "", cmp)
    if (cmp == d) break
    body = body line "\n"
  }
  return j
}
function heredocs(   k) {
  for (k = 1; k <= nh; k++) { i = read_body(i, delim[k], strip[k]); print "\\h" encoded(body) }
  nh = 0
}
# Position of the ")" that closes a "$(" whose text starts at p (n + 1 when unclosed). Quotes,
# nested substitutions, comments and heredoc bodies are skipped, so a `"` or `)` inside them does
# not end it early.
function subst_end(p,   j, ch, depth, q, k, cnt, lvl) {
  lvl = ++level; cnt = 0; depth = 0; q = ""
  for (j = p; j <= n; j++) {
    ch = substr(src, j, 1)
    if (q == "'") { if (ch == "'") q = ""; continue }
    if (q == "\"") {
      if (ch == "\\") j++
      else if (ch == "\"") q = ""
      else if (ch == "$" && substr(src, j + 1, 1) == "(") j = subst_end(j + 2)
      continue
    }
    if (ch == "\\") { j++; continue }
    if (ch == "'" || ch == "\"") { q = ch; continue }
    if (ch == "$" && substr(src, j + 1, 1) == "(") { j = subst_end(j + 2); continue }
    if (ch == "#" && substr(src, j - 1, 1) ~ /[ \t\n;&|(]/) {
      while (j < n && substr(src, j + 1, 1) != "\n") j++
      continue
    }
    if (ch == "(") { depth++; continue }
    if (ch == ")") {
      if (depth == 0) { level--; return j }
      depth--; continue
    }
    if (ch == "<" && substr(src, j + 1, 1) == "<") {
      if (substr(src, j + 2, 1) == "<") { j += 2; continue }
      j = read_delim(j + 1)
      cnt++; sdelim[lvl, cnt] = hd_delim; sstrip[lvl, cnt] = hd_strip
      continue
    }
    if (ch == "\n") {
      for (k = 1; k <= cnt; k++) j = read_body(j, sdelim[lvl, k], sstrip[lvl, k])
      cnt = 0
    }
  }
  level--
  return n + 1
}
# At "$(": emits the substitution's script as one `\s` word and moves past its ")".
function substitution(   e) {
  e = subst_end(i + 2)
  print "\\s" encoded(substr(src, i + 2, e - i - 2))
  i = e
}
{ src = src (NR > 1 ? "\n" : "") $0 }
END {
  n = length(src); q = ""; tok = ""; have = 0; drop = 0; herestring = 0; nh = 0; level = 0
  for (i = 1; i <= n; i++) {
    c = substr(src, i, 1)
    if (q == "'") { if (c == "'") q = ""; else add(c); continue }
    if (q == "\"") {
      if (c == "\"") { q = ""; continue }
      if (c == "\\") {
        nx = next_char()
        if (nx == "\n") { i++; continue }
        if (nx == "\"" || nx == "\\" || nx == "$" || nx == "`") { add(nx); i++; continue }
      }
      if (c == "$" && next_char() == "(") { substitution(); continue }
      add(c); continue
    }
    if (c == "\\") { nx = next_char(); i++; if (nx != "\n" && nx != "") add(nx); continue }
    if (c == "$" && next_char() == "(") { substitution(); have = 1; continue }
    if (c == "'" || c == "\"") { q = c; have = 1; continue }
    if (c == " " || c == "\t") { flush(); continue }
    if (c == "#" && !have) { while (i < n && next_char() != "\n") i++; continue }
    if (c == "\n") { flush(); heredocs(); sep("\\;"); continue }
    if (c == "<" && next_char() == "<") {
      if (have && tok ~ /^[0-9]+$/) { tok = ""; have = 0 } else flush()
      i++
      if (next_char() == "<") { i++; herestring = 1; continue }
      i = read_delim(i)
      nh++; delim[nh] = hd_delim; strip[nh] = hd_strip
      continue
    }
    if (c == "<" || c == ">" || (c == "&" && next_char() == ">")) {
      if (have && tok ~ /^[0-9]+$/) { tok = ""; have = 0 } else flush()
      while (next_char() ~ /[<>|]/) i++
      if (next_char() == "&") { i++; while (next_char() ~ /[0-9-]/) i++ } else drop = 1
      continue
    }
    if (c == "|") {
      if (next_char() == "|") { i++; sep("\\;"); continue }
      if (next_char() == "&") i++
      sep("\\|"); continue
    }
    if (c == ";" || c == "&" || c == "(" || c == ")" || c == "`") { sep("\\;"); continue }
    add(c)
  }
  flush()
  print "\\;"
}
AWK

decode() { printf '%b' "$1"; }

# `git push` with a force flag. Clusters such as `-uf` count: `f` is push's only short force flag,
# and the other letters allowed are push's short flags that take no value. A `+` refspec forces its
# one ref, and --mirror force-updates and deletes every remote ref, so both count as force.
short_force='^-[46dnquv]*f[46dfnquv]*$'
# `git add -f` / `--force` stages an ignored file, such as a secrets file kept out of git on purpose; the
# letters are add's short flags, none of which takes a value.
short_add_force='^-[A-Za-z]*f[A-Za-z]*$'

check_push() { # index of the word after `push`
  local j=$1 t
  while [ "$j" -lt "$n" ]; do
    t="${a[j]}"
    case "$t" in
      --force|--force-with-lease|--force-with-lease=*|--mirror|+*) block "force push ($t)" ;;
    esac
    if [[ $t =~ $short_force ]]; then block "force push ($t)"; fi
    j=$((j + 1))
  done
  return 0
}

# History stays linear: a merge is a fast-forward (`--ff-only`), never `--no-ff`, a squash or a
# merge commit. Finishing or leaving a merge that is already under way is not a new merge.
check_merge() { # index of the word after `merge`
  local j=$1 t ff_only=0 under_way=0
  while [ "$j" -lt "$n" ]; do
    t="${a[j]}"
    case "$t" in
      --no-ff) block "git merge --no-ff (history stays linear: rebase, then --ff-only)" ;;
      --ff-only) ff_only=1 ;;
      --abort|--continue|--quit) under_way=1 ;;
    esac
    j=$((j + 1))
  done
  if [ "$ff_only" -eq 0 ] && [ "$under_way" -eq 0 ]; then
    block "git merge without --ff-only (history stays linear: rebase, then --ff-only)"
  fi
  return 0
}

# A pull either fast-forwards or rebases; the default merges (and may create a merge commit).
check_pull() { # index of the word after `pull`
  local j=$1 t ff_only=0 rebase=0
  while [ "$j" -lt "$n" ]; do
    t="${a[j]}"
    case "$t" in
      --no-ff) block "git pull --no-ff (history stays linear)" ;;
      --ff-only) ff_only=1 ;;
      --rebase|--rebase=true|--rebase=merges|--rebase=interactive|-r) rebase=1 ;;
    esac
    j=$((j + 1))
  done
  if [ "$ff_only" -eq 0 ] && [ "$rebase" -eq 0 ]; then
    block "git pull without --ff-only or --rebase (history stays linear)"
  fi
  return 0
}

check_add() { # index of the word after `add`
  local j=$1 t
  while [ "$j" -lt "$n" ]; do
    t="${a[j]}"
    if [ "$t" = -- ]; then break; fi
    if [ "$t" = --force ] || [[ $t =~ $short_add_force ]]; then block "git add $t (it stages ignored files)"; fi
    j=$((j + 1))
  done
  return 0
}

check_git() { # index of the word after `git`
  local j=$1 sub
  while [ "$j" -lt "$n" ]; do
    case "${a[j]}" in
      -C|-c|--git-dir|--work-tree|--namespace) j=$((j + 2)) ;;
      -*) j=$((j + 1)) ;;
      *) break ;;
    esac
  done
  if [ "$j" -ge "$n" ]; then return 0; fi
  sub="${a[j]}"
  j=$((j + 1))
  case "$sub" in
    push) check_push "$j" ;;
    merge) check_merge "$j" ;;
    pull) check_pull "$j" ;;
    add) check_add "$j" ;;
  esac
  return 0
}

# A shell's `-c` script and any heredoc / here-string it reads are scripts too.
check_shell() { # index of the word after the shell
  local j=$1 t script_next=0 k=0
  while [ "$j" -lt "$n" ]; do
    t="${a[j]}"
    case "$t" in
      --*) ;;
      -*c*) script_next=1 ;;
      -*) ;;
      *)
        if [ "$script_next" -eq 1 ]; then
          check_script "$(decode "$t")" $((depth + 1))
          script_next=0
        fi ;;
    esac
    j=$((j + 1))
  done
  while [ "$k" -lt "${#bodies[@]}" ]; do
    check_script "$(decode "${bodies[k]}")" $((depth + 1))
    k=$((k + 1))
  done
  return 0
}

check_eval() { # index of the word after `eval`
  local j=$1 joined=""
  while [ "$j" -lt "$n" ]; do
    joined="$joined $(decode "${a[j]}")"
    j=$((j + 1))
  done
  check_script "$joined" $((depth + 1))
}

# Looks for the guarded programs anywhere in the simple command, so `env X=1 git …` and
# `sudo git …` are covered without knowing every wrapper.
# Tagged words are set apart first, so a `"$(…)"` argument keeps its place as one plain word.
check_simple() { # depth word…
  local depth=$1 word i=0 n prog
  shift
  local -a a bodies
  a=()
  bodies=()
  for word in "$@"; do
    case "$word" in
      '\s'*) check_script "$(decode "${word#'\s'}")" $((depth + 1)) ;;
      '\h'*) bodies[${#bodies[@]}]="${word#'\h'}" ;;
      *) a[${#a[@]}]="$word" ;;
    esac
  done
  n=${#a[@]}
  while [ "$i" -lt "$n" ]; do
    # APFS ignores case, so `GIT` runs git: the program name is matched in any case. The option is
    # scoped to this match only, so options and subcommands stay case-sensitive.
    shopt -s nocasematch
    case "${a[i]##*/}" in
      git) prog=git ;;
      sh|bash|zsh|dash|ksh) prog=shell ;;
      eval) prog=eval ;;
      *) prog="" ;;
    esac
    shopt -u nocasematch
    case "$prog" in
      git) check_git $((i + 1)) ;;
      shell) check_shell $((i + 1)) ;;
      eval) check_eval $((i + 1)) ;;
    esac
    i=$((i + 1))
  done
  return 0
}

# Splits a script into simple commands and checks each one.
check_script() { # script depth
  local line tokens
  local -a words
  if [ "$2" -gt "$MAX_DEPTH" ]; then block "a script nested too deep to check (over $MAX_DEPTH levels)"; fi
  # A failed tokenizer leaves no words, or a cut-off list, which would read as nothing to block.
  # Its status is lost inside `< <(…)`, so the words are captured first and the failure is said.
  if ! tokens="$(printf '%s\n' "$1" | LC_ALL=C awk "$tokenizer")"; then
    allow_with_warning "the tokenizer failed"
  fi
  words=()
  while IFS= read -r line; do
    case "$line" in
      '\;' | '\|')
        if [ "${#words[@]}" -gt 0 ]; then check_simple "$2" "${words[@]}"; fi
        words=() ;;
      *) words[${#words[@]}]="$line" ;;
    esac
  done <<< "$tokens"
  return 0
}

if ! command -v jq >/dev/null 2>&1; then allow_with_warning "jq is not installed"; fi
input="$(cat)"
if ! command="$(printf '%s' "$input" | jq -r '.tool_input.command // empty' 2>/dev/null)"; then
  allow_with_warning "the hook input is not the expected JSON"
fi
if [ -z "$command" ]; then exit 0; fi

check_script "$command" 0
exit 0
