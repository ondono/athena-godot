#!/usr/bin/env sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPO_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
WORKSPACE_DIR=$(CDPATH= cd -- "$REPO_DIR/../.." && pwd)
PRESET="${1:-}"
IMAGE_TAG="${ATHENA_DEBIAN12_IMAGE_TAG:-athena-plugin-godot-debian12:bookworm}"
DEPLOY_PROJECT=""

usage() {
    echo "usage: $0 <linux-x86_64-release|debian12-aarch64-release> [--deploy /path/to/godot-project]" >&2
}

if [ "$#" -gt 0 ]; then
    shift
fi

while [ "$#" -gt 0 ]; do
    case "$1" in
        --deploy)
            if [ "$#" -lt 2 ]; then
                usage
                echo "--deploy requires a Godot project path" >&2
                exit 2
            fi
            DEPLOY_PROJECT=$2
            shift 2
            ;;
        *)
            usage
            echo "unsupported argument: $1" >&2
            exit 2
            ;;
    esac
done

case "$PRESET" in
    linux-x86_64-release)
        DEPS_TARGET="linux-x86_64"
        ABI_PRESET="check-abi-linux-x86_64-release"
        PACKAGE_PRESET="package-runtime"
        ;;
    debian12-aarch64-release)
        if [ -n "$DEPLOY_PROJECT" ]; then
            usage
            echo "--deploy is currently supported only for linux-x86_64-release" >&2
            exit 2
        fi
        DEPS_TARGET="debian12-aarch64"
        ABI_PRESET="check-abi-debian12-aarch64-release"
        PACKAGE_PRESET=""
        ;;
    "")
        usage
        exit 2
        ;;
    *)
        usage
        echo "unsupported Debian 12 build preset: $PRESET" >&2
        exit 2
        ;;
esac

find_runtime() {
    if [ -n "${CONTAINER_RUNTIME:-}" ]; then
        command -v "$CONTAINER_RUNTIME" >/dev/null 2>&1 || {
            echo "CONTAINER_RUNTIME is set but not executable: $CONTAINER_RUNTIME" >&2
            exit 1
        }
        printf '%s\n' "$CONTAINER_RUNTIME"
        return
    fi

    if command -v podman >/dev/null 2>&1; then
        printf 'podman\n'
        return
    fi

    if command -v docker >/dev/null 2>&1; then
        printf 'docker\n'
        return
    fi

    echo "No container runtime found. Install podman or docker, or set CONTAINER_RUNTIME." >&2
    exit 1
}

detect_jobs() {
    if [ -n "${JOBS:-}" ]; then
        case "$JOBS" in
            ''|*[!0-9]*|0)
                echo "JOBS must be a positive integer, got: $JOBS" >&2
                exit 2
                ;;
        esac
        printf '%s\n' "$JOBS"
        return
    fi

    if command -v nproc >/dev/null 2>&1; then
        nproc
        return
    fi

    if command -v getconf >/dev/null 2>&1; then
        getconf _NPROCESSORS_ONLN
        return
    fi

    printf '1\n'
}

RUNTIME=$(find_runtime)
BUILD_JOBS=$(detect_jobs)
UID_VALUE=$(id -u)
GID_VALUE=$(id -g)

echo "Selected build jobs: $BUILD_JOBS"

"$RUNTIME" build \
    -f "$REPO_DIR/ci/debian12/Dockerfile" \
    -t "$IMAGE_TAG" \
    "$REPO_DIR"

CONTAINER_SCRIPT='set -eu
cd "$ATHENA_REPO_DIR"
echo "Selected build jobs: $ATHENA_BUILD_JOBS"
./scripts/provision-deps.sh "$ATHENA_DEPS_TARGET"
cmake --fresh --preset "$ATHENA_PRESET"
cmake --build --preset "$ATHENA_PRESET" --parallel "$ATHENA_BUILD_JOBS"
cmake --build --preset "$ATHENA_ABI_PRESET" --parallel "$ATHENA_BUILD_JOBS"
if [ -n "$ATHENA_PACKAGE_PRESET" ]; then
    cmake --build --preset "$ATHENA_PACKAGE_PRESET" --parallel "$ATHENA_BUILD_JOBS"
fi
'

RUN_ARGS=""
if [ "$RUNTIME" = "docker" ]; then
    RUN_ARGS="$RUN_ARGS --user $UID_VALUE:$GID_VALUE"
fi

if [ "$RUNTIME" = "podman" ]; then
    RUN_ARGS="$RUN_ARGS --userns=keep-id"
fi

# Mount the workspace root, not only this repo, because the preset references
# the native Athena source at ../../software/athena-plugin.
# shellcheck disable=SC2086
"$RUNTIME" run --rm \
    $RUN_ARGS \
    -e ATHENA_REPO_DIR="$REPO_DIR" \
    -e ATHENA_PRESET="$PRESET" \
    -e ATHENA_DEPS_TARGET="$DEPS_TARGET" \
    -e ATHENA_ABI_PRESET="$ABI_PRESET" \
    -e ATHENA_PACKAGE_PRESET="$PACKAGE_PRESET" \
    -e ATHENA_BUILD_JOBS="$BUILD_JOBS" \
    -e CMAKE_BUILD_PARALLEL_LEVEL="$BUILD_JOBS" \
    -e MAKEFLAGS="-j$BUILD_JOBS" \
    -e NINJAFLAGS="-j$BUILD_JOBS" \
    -v "$WORKSPACE_DIR:$WORKSPACE_DIR" \
    -w "$REPO_DIR" \
    "$IMAGE_TAG" \
    /bin/sh -lc "$CONTAINER_SCRIPT"

if [ -n "$DEPLOY_PROJECT" ]; then
    "$REPO_DIR/scripts/deploy.sh" "$DEPLOY_PROJECT"
fi
