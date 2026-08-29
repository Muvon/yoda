#!/usr/bin/env bash
# Shared helpers for yoda bats tests.
# Load from tests/*.bats with:     load helpers
# Load from tests/lib/*.bats with: load ../helpers

TESTS_DIR="${BASH_SOURCE[0]%/*}"
YODA_ROOT="$(cd "$TESTS_DIR/.." && pwd)"
YODA="$YODA_ROOT/yoda"

# Lib scripts source each other via $YODA_PATH
export YODA_PATH="$YODA_ROOT"

# Normally exported by a project's .yodarc
export YODA_VAR_REGEX='%(\{[A-Z_]+\})'
