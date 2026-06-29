#!/usr/bin/env sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
BUILD_DIR="${BUILD_DIR:-$SCRIPT_DIR/build/linux-depthai-release}"
BUILD_TYPE="${BUILD_TYPE:-Release}"
GODOT_CPP_DIR="${GODOT_CPP_DIR:-$SCRIPT_DIR/third_party/godot-cpp}"
ATHENA_NATIVE_PLUGIN_DIR="${ATHENA_NATIVE_PLUGIN_DIR:-$SCRIPT_DIR/../../software/athena-plugin}"
ATHENA_ENABLE_DEPTHAI="${ATHENA_ENABLE_DEPTHAI:-ON}"
ATHENA_DEPTHAI_API_VERSION="${ATHENA_DEPTHAI_API_VERSION:-2}"
ATHENA_DEPTHAI_PACKAGE_DIR="${ATHENA_DEPTHAI_PACKAGE_DIR:-$ATHENA_NATIVE_PLUGIN_DIR/build/depthai-v229-install-static-pic-localhunter}"
TARGET="${TARGET:-athena_godot}"

"$SCRIPT_DIR/tools/bootstrap-godot-cpp.sh"

if [ "$ATHENA_ENABLE_DEPTHAI" = "ON" ] && [ ! -f "$ATHENA_DEPTHAI_PACKAGE_DIR/lib/cmake/depthai/depthaiConfig.cmake" ]; then
    echo "DepthAI package missing; building it through native Athena build.sh"
    (cd "$ATHENA_NATIVE_PLUGIN_DIR" && TARGET=build PRESET=linux-clang-depthai-v229-package-release ./build.sh)
fi

cmake -S "$SCRIPT_DIR" -B "$BUILD_DIR" \
    -DCMAKE_BUILD_TYPE="$BUILD_TYPE" \
    -DGODOT_CPP_DIR="$GODOT_CPP_DIR" \
    -DATHENA_NATIVE_PLUGIN_DIR="$ATHENA_NATIVE_PLUGIN_DIR" \
    -DATHENA_ENABLE_DEPTHAI="$ATHENA_ENABLE_DEPTHAI" \
    -DATHENA_DEPTHAI_API_VERSION="$ATHENA_DEPTHAI_API_VERSION" \
    -DATHENA_DEPTHAI_PACKAGE_DIR="$ATHENA_DEPTHAI_PACKAGE_DIR"

cmake --build "$BUILD_DIR" --target "$TARGET"
