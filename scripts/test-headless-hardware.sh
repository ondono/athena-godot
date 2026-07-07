#!/usr/bin/env sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPO_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
GODOT_BIN=${GODOT_BIN:-godot}

exec "$GODOT_BIN" --headless --path "$REPO_DIR/project" \
    --log-file "${TMPDIR:-/tmp}/athena-godot-headless.log" \
    --script res://tests/headless_smoke.gd -- "$@"
