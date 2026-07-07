#!/usr/bin/env sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
PRESET="${PRESET:-debian12-aarch64-release}"

"$SCRIPT_DIR/build-plugin.sh" "$PRESET"
