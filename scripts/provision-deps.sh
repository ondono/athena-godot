#!/usr/bin/env sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPO_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
TARGET="${1:-}"

usage() {
    echo "usage: $0 <linux-x86_64|debian12-aarch64>" >&2
}

case "$TARGET" in
    linux-x86_64|debian12-aarch64) ;;
    "")
        usage
        exit 2
        ;;
    *)
        usage
        echo "unsupported dependency target: $TARGET" >&2
        exit 2
        ;;
esac

for command in cmake git curl tar awk sort; do
    command -v "$command" >/dev/null 2>&1 || {
        echo "Required command not found: $command" >&2
        exit 1
    }
done

version_gt() {
    highest=$(printf '%s\n%s\n' "$1" "$2" | sort -V | tail -n 1)
    [ "$highest" = "$1" ] && [ "$1" != "$2" ]
}

host_glibc_version() {
    ldd --version 2>/dev/null | awk 'NR == 1 { print $NF }'
}

DEPS_PREFIX="$REPO_DIR/build/deps/$TARGET"
PROVISION_BUILD_DIR="$REPO_DIR/build/provision/$TARGET"
TOOLCHAIN_FILE=""

if [ "$TARGET" = "linux-x86_64" ]; then
    glibc_version=$(host_glibc_version)
    if [ -z "$glibc_version" ]; then
        echo "Could not determine host glibc version." >&2
        exit 1
    fi
    if version_gt "$glibc_version" "2.36"; then
        echo "Refusing to provision linux-x86_64 release dependencies on glibc $glibc_version." >&2
        echo "Build these dependencies inside a Debian 12 x86_64 container/sysroot so artifacts do not exceed GLIBC_2.36." >&2
        exit 1
    fi
fi

if [ "$TARGET" = "debian12-aarch64" ]; then
    TOOLCHAIN_FILE="$REPO_DIR/cmake/toolchains/debian12-aarch64.cmake"
    if [ ! -d "$REPO_DIR/build/sysroots/debian12-arm64/usr/include" ]; then
        echo "Debian 12 ARM64 sysroot is missing." >&2
        echo "Run ./tools/bootstrap-debian12-sysroot.sh before provisioning $TARGET." >&2
        exit 1
    fi
fi

mkdir -p "$DEPS_PREFIX" "$PROVISION_BUILD_DIR"

cmake_args="-S $REPO_DIR/cmake/provision -B $PROVISION_BUILD_DIR -DATHENA_PROVISION_TARGET=$TARGET -DATHENA_DEPS_PREFIX=$DEPS_PREFIX"
if [ -n "$TOOLCHAIN_FILE" ]; then
    cmake_args="$cmake_args -DATHENA_TARGET_TOOLCHAIN_FILE=$TOOLCHAIN_FILE"
fi

# shellcheck disable=SC2086
cmake $cmake_args
cmake --build "$PROVISION_BUILD_DIR" --target verify-provisioned-deps
