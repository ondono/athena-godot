#!/usr/bin/env sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPO_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
OUTPUT_DIR="${OUTPUT_DIR:-$REPO_DIR/dist/athena-addon}"
OUTPUT_DIR=$(realpath -m -- "$OUTPUT_DIR")

case "$OUTPUT_DIR" in
    /|"$REPO_DIR"|"$REPO_DIR/project"|"$REPO_DIR/project/bin")
        echo "Refusing unsafe addon output directory: $OUTPUT_DIR" >&2
        exit 2
        ;;
esac
case "$REPO_DIR/" in
    "$OUTPUT_DIR/"*)
        echo "Refusing addon output directory containing the repository: $OUTPUT_DIR" >&2
        exit 2
        ;;
esac

STAGING_DIR="$OUTPUT_DIR.tmp.$$"
ADDON_DIR="$STAGING_DIR/addons/athena"
trap 'rm -rf "$STAGING_DIR"' EXIT HUP INT TERM

rm -rf "$STAGING_DIR"
mkdir -p "$ADDON_DIR/bin/linux-arm64"
sed 's#res://bin/#res://addons/athena/bin/#g' \
    "$REPO_DIR/project/bin/athena_godot.gdextension" \
    > "$ADDON_DIR/athena_godot.gdextension"

copy_pair() {
    source_dir=$1
    destination_dir=$2
    if [ ! -f "$source_dir/libathena_godot.so" ] || [ ! -f "$source_dir/libathena_plugin.so" ]; then
        return
    fi
    mkdir -p "$destination_dir"
    cp "$source_dir/libathena_godot.so" "$source_dir/libathena_plugin.so" "$destination_dir/"
}

copy_pair "$REPO_DIR/project/bin" "$ADDON_DIR/bin"
copy_pair "$REPO_DIR/project/bin/linux-arm64" "$ADDON_DIR/bin/linux-arm64"

if [ ! -f "$ADDON_DIR/bin/libathena_godot.so" ] &&
   [ ! -f "$ADDON_DIR/bin/linux-arm64/libathena_godot.so" ]; then
    echo "No built Athena GDExtension was found." >&2
    exit 1
fi

(
    cd "$STAGING_DIR"
    find . -type f ! -name SHA256SUMS -print0 | sort -z | xargs -0 sha256sum > SHA256SUMS
)

rm -rf "$OUTPUT_DIR"
mv "$STAGING_DIR" "$OUTPUT_DIR"
trap - EXIT HUP INT TERM
echo "Athena addon ready: $OUTPUT_DIR"
