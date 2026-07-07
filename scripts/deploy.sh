#!/usr/bin/env sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPO_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
PACKAGE_ADDON_DIR="$REPO_DIR/dist/x86_64/athena-runtime/addons/athena"

usage() {
    echo "usage: $0 /path/to/godot-project" >&2
}

if [ "$#" -ne 1 ]; then
    usage
    exit 2
fi

DEST_PROJECT=$1

if [ ! -d "$DEST_PROJECT" ]; then
    echo "Destination is not a directory: $DEST_PROJECT" >&2
    exit 2
fi

if [ ! -f "$DEST_PROJECT/project.godot" ]; then
    echo "Destination does not appear to be a Godot project: $DEST_PROJECT" >&2
    echo "Expected to find project.godot." >&2
    exit 2
fi

if [ ! -d "$PACKAGE_ADDON_DIR" ]; then
    echo "Packaged Athena addon was not found: $PACKAGE_ADDON_DIR" >&2
    echo "Run: cmake --build --preset package-runtime" >&2
    exit 1
fi

mkdir -p "$DEST_PROJECT/addons"
if command -v rsync >/dev/null 2>&1; then
    rsync -a --delete "$PACKAGE_ADDON_DIR/" "$DEST_PROJECT/addons/athena/"
else
    rm -rf "$DEST_PROJECT/addons/athena"
    mkdir -p "$DEST_PROJECT/addons/athena"
    cp -a "$PACKAGE_ADDON_DIR/." "$DEST_PROJECT/addons/athena/"
fi
echo "Deployed Athena addon to $DEST_PROJECT/addons/athena"
