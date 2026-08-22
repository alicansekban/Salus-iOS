#!/bin/bash
#
# Formatting + lint gate. CI and humans call this same script.
#
# Order matters: SwiftFormat runs first because SwiftLint's `--strict` budget is
# zero warnings, and a formatting difference would otherwise be reported twice.
#
# BOTH tools are run over the WHOLE REPOSITORY from the repo root, deliberately:
#
#   * `swiftformat --lint .`  — the `--exclude` list in .swiftformat prunes
#     .build/.swiftpm/etc., so "." is the cheap and complete scope.
#
#   * `swiftlint --strict`    — NEVER add `--path`. The custom
#     `no_ui_framework_in_domain` rule scopes itself with `included:` regexes
#     that are matched against the path SwiftLint resolves per file, and
#     `--path` changes that resolution enough that the rule matches nothing and
#     SILENTLY PASSES. Measured against a planted `import SwiftUI` in
#     SalusModel: repo-wide -> 1 hit, positional file arg -> 1 hit,
#     `--path` -> 0 hits. The long-form warning is in .swiftlint.yml.
#     If a faster changed-files-only mode is ever wanted, pass the files
#     POSITIONALLY (`swiftlint --strict FileA.swift FileB.swift`), never
#     via `--path`.
#
# A formatting pass (as opposed to this check) is:
#   swiftformat . && swiftlint --fix
# in that order -- see the note in .swiftformat about `] as [T]` casts.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

echo "==> swiftformat --lint ."
swiftformat --lint .

echo
echo "==> swiftlint --strict"
swiftlint --strict
