#!/usr/bin/env sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
GODOT_CPP_DIR="${GODOT_CPP_DIR:-$SCRIPT_DIR/third_party/godot-cpp}"
ATHENA_NATIVE_PLUGIN_DIR="${ATHENA_NATIVE_PLUGIN_DIR:-$SCRIPT_DIR/../../software/athena-plugin}"
TARGET="${TARGET:-athena_godot}"
BUILD_TYPE="${BUILD_TYPE:-Release}"
ATHENA_AARCH64_TARGET="${ATHENA_AARCH64_TARGET:-aarch64-linux-gnu}"

# Defaults to a simulated/no-DepthAI build so the GDExtension and sample scene can
# be compiled before ARM64 DepthAI/OpenCV packages are available.
ATHENA_ENABLE_DEPTHAI="${ATHENA_ENABLE_DEPTHAI:-OFF}"
ATHENA_DEPTHAI_PACKAGE_DIR="${ATHENA_DEPTHAI_PACKAGE_DIR:-}"
ATHENA_OPENCV_PACKAGE_DIR="${ATHENA_OPENCV_PACKAGE_DIR:-}"
DEPTHAI_DIR="${DEPTHAI_DIR:-}"
OpenCV_DIR="${OpenCV_DIR:-$ATHENA_OPENCV_PACKAGE_DIR}"

if [ -z "$DEPTHAI_DIR" ] && [ -n "$ATHENA_DEPTHAI_PACKAGE_DIR" ]; then
    DEPTHAI_DIR="$ATHENA_DEPTHAI_PACKAGE_DIR/lib/cmake/depthai"
fi

if [ "$(uname -m)" = "aarch64" ] || [ "$(uname -m)" = "arm64" ]; then
    BUILD_DIR="${BUILD_DIR:-$SCRIPT_DIR/build/rockpi-native-release}"
    "$SCRIPT_DIR/tools/bootstrap-godot-cpp.sh"
    cmake -S "$SCRIPT_DIR" -B "$BUILD_DIR" \
        -DCMAKE_BUILD_TYPE="$BUILD_TYPE" \
        -DGODOT_CPP_DIR="$GODOT_CPP_DIR" \
        -DATHENA_NATIVE_PLUGIN_DIR="$ATHENA_NATIVE_PLUGIN_DIR" \
        -DATHENA_ENABLE_DEPTHAI="$ATHENA_ENABLE_DEPTHAI" \
        -DATHENA_DEPTHAI_PACKAGE_DIR="$ATHENA_DEPTHAI_PACKAGE_DIR" \
        -DATHENA_OPENCV_PACKAGE_DIR="$ATHENA_OPENCV_PACKAGE_DIR" \
        -Ddepthai_DIR="$DEPTHAI_DIR" \
        -DOpenCV_DIR="$OpenCV_DIR" \
        -DATHENA_GODOT_OUTPUT_SUBDIR=linux-arm64 \
        -DGODOTCPP_TARGET=template_release
else
    BUILD_DIR="${BUILD_DIR:-$SCRIPT_DIR/build/rockpi-aarch64-release}"
    ATHENA_AARCH64_SYSROOT="${ATHENA_AARCH64_SYSROOT:-}"

    "$SCRIPT_DIR/tools/bootstrap-godot-cpp.sh"
    cmake -S "$SCRIPT_DIR" -B "$BUILD_DIR" \
        -DCMAKE_BUILD_TYPE="$BUILD_TYPE" \
        -DCMAKE_TOOLCHAIN_FILE="$SCRIPT_DIR/cmake/toolchains/linux-aarch64-clang.cmake" \
        -DATHENA_AARCH64_TARGET="$ATHENA_AARCH64_TARGET" \
        -DATHENA_AARCH64_SYSROOT="$ATHENA_AARCH64_SYSROOT" \
        -DGODOT_CPP_DIR="$GODOT_CPP_DIR" \
        -DATHENA_NATIVE_PLUGIN_DIR="$ATHENA_NATIVE_PLUGIN_DIR" \
        -DATHENA_ENABLE_DEPTHAI="$ATHENA_ENABLE_DEPTHAI" \
        -DATHENA_DEPTHAI_PACKAGE_DIR="$ATHENA_DEPTHAI_PACKAGE_DIR" \
        -DATHENA_OPENCV_PACKAGE_DIR="$ATHENA_OPENCV_PACKAGE_DIR" \
        -Ddepthai_DIR="$DEPTHAI_DIR" \
        -DOpenCV_DIR="$OpenCV_DIR" \
        -DATHENA_GODOT_OUTPUT_SUBDIR=linux-arm64 \
        -DGODOTCPP_TARGET=template_release
fi

cmake --build "$BUILD_DIR" --target "$TARGET"
