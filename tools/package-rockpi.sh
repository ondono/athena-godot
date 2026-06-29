#!/usr/bin/env sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPO_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
SYSROOT="${ATHENA_AARCH64_SYSROOT:-$REPO_DIR/build/sysroots/archlinuxarm-aarch64}"
GODOT_BIN="${GODOT_ARM64_BIN:-$REPO_DIR/build/godot-4.7-arm64/Godot_v4.7-stable_linux.arm64}"
OUTPUT_DIR="${OUTPUT_DIR:-$REPO_DIR/dist/athena-godot-rockpi-arm64}"
PROJECT_OUT="$OUTPUT_DIR/project"
LIB_OUT="$PROJECT_OUT/bin/linux-arm64"

if [ ! -f "$REPO_DIR/project/bin/linux-arm64/libathena_godot.so" ] ||
   [ ! -f "$REPO_DIR/project/bin/linux-arm64/libathena_plugin.so" ]; then
    echo "ARM64 Athena binaries are missing. Run the hardware build first." >&2
    exit 1
fi

if [ ! -x "$GODOT_BIN" ]; then
    echo "Godot ARM64 executable is missing or not executable: $GODOT_BIN" >&2
    exit 1
fi

rm -rf "$OUTPUT_DIR"
mkdir -p "$LIB_OUT" "$PROJECT_OUT/debug" "$PROJECT_OUT/samples" "$PROJECT_OUT/tests"

cp "$GODOT_BIN" "$OUTPUT_DIR/godot"
cp "$REPO_DIR/project/project.godot" "$PROJECT_OUT/"
cp "$REPO_DIR/project/bin/athena_godot.gdextension" "$PROJECT_OUT/bin/"
cp "$REPO_DIR/project/bin/athena_godot.gdextension.uid" "$PROJECT_OUT/bin/"
cp "$REPO_DIR/project/bin/linux-arm64/libathena_godot.so" "$LIB_OUT/"
cp "$REPO_DIR/project/bin/linux-arm64/libathena_plugin.so" "$LIB_OUT/"
cp "$REPO_DIR/project/debug/"*.gd "$REPO_DIR/project/debug/"*.tscn "$PROJECT_OUT/debug/"
cp "$REPO_DIR/project/samples/"*.gd "$REPO_DIR/project/samples/"*.tscn "$PROJECT_OUT/samples/"
cp "$REPO_DIR/project/tests/"*.gd "$PROJECT_OUT/tests/"

is_system_library() {
    case "$1" in
        ld-linux-aarch64.so.1|libc.so.6|libdl.so.2|libm.so.6|libpthread.so.0|librt.so.1)
            return 0
            ;;
    esac
    return 1
}

find_sysroot_library() {
    for directory in \
        "$SYSROOT/usr/lib" \
        "$SYSROOT/lib" \
        "$SYSROOT/usr/lib64" \
        "$SYSROOT/lib64"; do
        if [ -e "$directory/$1" ]; then
            printf '%s\n' "$directory/$1"
            return 0
        fi
    done
    return 1
}

QUEUE="$OUTPUT_DIR/.dependency-queue"
SEEN="$OUTPUT_DIR/.dependency-seen"
printf '%s\n%s\n' \
    "$LIB_OUT/libathena_godot.so" \
    "$LIB_OUT/libathena_plugin.so" > "$QUEUE"
: > "$SEEN"

while [ -s "$QUEUE" ]; do
    CURRENT=$(sed -n '1p' "$QUEUE")
    sed '1d' "$QUEUE" > "$QUEUE.next"
    mv "$QUEUE.next" "$QUEUE"

    if grep -Fqx "$CURRENT" "$SEEN"; then
        continue
    fi
    printf '%s\n' "$CURRENT" >> "$SEEN"

    readelf -d "$CURRENT" 2>/dev/null |
        sed -n 's/.*Shared library: \[\(.*\)\]/\1/p' |
        while IFS= read -r NEEDED; do
            if is_system_library "$NEEDED"; then
                continue
            fi

            if [ -e "$LIB_OUT/$NEEDED" ]; then
                printf '%s\n' "$LIB_OUT/$NEEDED" >> "$QUEUE"
                continue
            fi

            SOURCE=$(find_sysroot_library "$NEEDED" || true)
            if [ -z "$SOURCE" ]; then
                echo "Unresolved ARM64 runtime library: $NEEDED" >&2
                exit 1
            fi

            cp -L "$SOURCE" "$LIB_OUT/$NEEDED"
            printf '%s\n' "$LIB_OUT/$NEEDED" >> "$QUEUE"
        done
done

rm -f "$QUEUE" "$SEEN"

for LIBRARY in "$LIB_OUT"/*; do
    if readelf -h "$LIBRARY" >/dev/null 2>&1; then
        patchelf --set-rpath '$ORIGIN' "$LIBRARY"
    fi
done

cat > "$OUTPUT_DIR/run.sh" <<'EOF'
#!/usr/bin/env sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
LIB_DIR="$ROOT/project/bin/linux-arm64"
export LD_LIBRARY_PATH="$LIB_DIR${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"

exec "$ROOT/godot" --path "$ROOT/project" "$@"
EOF

cat > "$OUTPUT_DIR/headless-test.sh" <<'EOF'
#!/usr/bin/env sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
LIB_DIR="$ROOT/project/bin/linux-arm64"
export LD_LIBRARY_PATH="$LIB_DIR${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"

exec "$ROOT/godot" --headless --path "$ROOT/project" \
    --log-file "${TMPDIR:-/tmp}/athena-godot-headless.log" \
    --script res://tests/headless_smoke.gd -- "$@"
EOF

cat > "$OUTPUT_DIR/README.txt" <<'EOF'
Athena Godot Rock Pi ARM64 bundle

Run:
  ./run.sh

Headless hardware smoke test:
  ./headless-test.sh
  ./headless-test.sh --timeout=30

Exit code 0 confirms that the GDExtension loaded, the real DepthAI backend
connected, IMU data arrived, and an RGB frame was copied successfully.

The bundle contains Godot 4.7, the sample stream/debug scene, the real
DepthAI-enabled Athena plugin, and its non-glibc runtime libraries.

The target must be an ARM64 Linux system with glibc and permission to access
the Luxonis USB device. No simulated backend is used by this build.
EOF

chmod +x "$OUTPUT_DIR/godot" "$OUTPUT_DIR/run.sh" "$OUTPUT_DIR/headless-test.sh"

(
    cd "$OUTPUT_DIR"
    find . -type f ! -name SHA256SUMS -print0 | sort -z | xargs -0 sha256sum > SHA256SUMS
)

echo "Rock Pi bundle ready: $OUTPUT_DIR"
