#!/bin/bash
#
# Runs the whole CI pipeline locally, in the same order and with the same
# commands as .github/workflows/ci.yml: lint -> test -> build.
#
# The workflow invokes the three scripts below as three separate steps so that
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
echo "# 1/3  lint"
echo "############################################################"
scripts/lint.sh

echo
echo "############################################################"
echo "# 2/3  test (all packages)"
echo "############################################################"
scripts/test-packages.sh

echo
echo "############################################################"
echo "# 3/3  build (app scheme)"
echo "############################################################"
scripts/build-app.sh

echo
echo "==> CI pipeline passed."
