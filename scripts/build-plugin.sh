#!/usr/bin/env sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPO_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
PRESET="${1:-${PRESET:-linux-x86_64-release}}"

cmake --preset "$PRESET" -S "$REPO_DIR"
cmake --build --preset "$PRESET"
