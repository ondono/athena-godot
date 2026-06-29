#!/usr/bin/env sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
GODOT_BIN=${GODOT_BIN:-godot}

exec "$GODOT_BIN" --headless --path "$ROOT/project" \
    --log-file "${TMPDIR:-/tmp}/athena-godot-headless.log" \
    --script res://tests/headless_smoke.gd -- "$@"
