#!/usr/bin/env sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPO_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
GODOT_BIN="${GODOT_BIN:-godot}"
GODOT_CPP_DIR="${GODOT_CPP_DIR:-$REPO_DIR/third_party/godot-cpp}"
GODOT_CPP_URL="${GODOT_CPP_URL:-https://github.com/godotengine/godot-cpp.git}"
GODOT_CPP_REF="${GODOT_CPP_REF:-}"
GODOT_CPP_UPDATE="${GODOT_CPP_UPDATE:-0}"
MODE="${1:-bootstrap}"

detect_godot_cpp_ref() {
    if [ -n "$GODOT_CPP_REF" ]; then
        printf '%s\n' "$GODOT_CPP_REF"
        return
    fi

    version=$("$GODOT_BIN" --version | awk -F. '{ print $1 "." $2 }')
    if git ls-remote --exit-code --heads "$GODOT_CPP_URL" "$version" >/dev/null 2>&1; then
        printf '%s\n' "$version"
        return
    fi

    echo "No godot-cpp branch named $version; falling back to master." >&2
    printf 'master\n'
}

REF=$(detect_godot_cpp_ref)

if [ "$MODE" = "--check" ]; then
    if [ ! -f "$GODOT_CPP_DIR/CMakeLists.txt" ]; then
        echo "missing godot-cpp checkout: $GODOT_CPP_DIR" >&2
        exit 1
    fi
    current_ref=$(git -C "$GODOT_CPP_DIR" rev-parse --abbrev-ref HEAD 2>/dev/null || true)
    current_commit=$(git -C "$GODOT_CPP_DIR" rev-parse --short HEAD 2>/dev/null || true)
    echo "godot-cpp ok: $GODOT_CPP_DIR ref=${current_ref:-detached} commit=${current_commit:-unknown}"
    exit 0
fi

if [ ! -d "$GODOT_CPP_DIR/.git" ]; then
    mkdir -p "$(dirname "$GODOT_CPP_DIR")"
    git clone --depth 1 --branch "$REF" "$GODOT_CPP_URL" "$GODOT_CPP_DIR"
elif [ "$GODOT_CPP_UPDATE" = "1" ]; then
    git -C "$GODOT_CPP_DIR" fetch --depth 1 origin "$REF"
    git -C "$GODOT_CPP_DIR" checkout FETCH_HEAD
else
    current_commit=$(git -C "$GODOT_CPP_DIR" rev-parse --short HEAD 2>/dev/null || true)
    echo "Using existing godot-cpp checkout at $GODOT_CPP_DIR commit=${current_commit:-unknown}."
fi

echo "godot-cpp ready: $GODOT_CPP_DIR ref=$REF"
