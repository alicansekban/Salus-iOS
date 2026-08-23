#!/bin/bash
#
# Runs the whole CI pipeline locally, in the same order and with the same
# commands as .github/workflows/ci.yml:
#
#   toolchain -> lint -> custom-rule fixtures -> test -> build
#
# The workflow invokes the five scripts below as five separate steps so that
# GitHub's UI shows which stage failed; this file is the single entry point for
# a human who just wants to know whether the tree is green before pushing.
#
#   scripts/ci.sh
#
# Nothing here is CI-specific, so what it prints is what the workflow prints.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

echo "############################################################"
echo "# 1/5  toolchain"
echo "############################################################"
scripts/check-toolchain.sh

echo
echo "############################################################"
echo "# 2/5  lint"
echo "############################################################"
scripts/lint.sh

echo
echo "############################################################"
echo "# 3/5  custom lint rules (planted fixtures)"
echo "############################################################"
# Not a second lint pass: it proves the .swiftlint.yml CUSTOM rules still fire.
# A custom rule is a regex plus an `included:` scope and both halves fail
# silently, so a rule that has stopped matching looks exactly like a clean tree.
# The script plants a fixture inside each rule's scope and an identical one
# outside it, and removes them on every exit path.
scripts/lint-custom-rules.sh

echo
echo "############################################################"
echo "# 4/5  test (all packages)"
echo "############################################################"
scripts/test-packages.sh

echo
echo "############################################################"
echo "# 5/5  build (app scheme)"
echo "############################################################"
scripts/build-app.sh

echo
echo "==> CI pipeline passed."
