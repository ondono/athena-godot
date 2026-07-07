# Build

This repo builds the Godot GDExtension wrapper around the real native Athena
plugin at `/home/xavi/projects/inmersia/software/athena-plugin`.

The supported presets are intentionally hardware-capable builds. Simulated,
no-camera, and no-DepthAI builds are not production profiles here.

## Dependency Rules

- `godot-cpp` must be present at `third_party/godot-cpp` or passed with
  `-DGODOT_CPP_DIR=/path/to/godot-cpp`.
- `ATHENA_DEPTHAI_PACKAGE_DIR` must point at an explicit DepthAI package prefix
  under `build/deps/<target>/depthai` containing
  `lib/cmake/depthai/depthaiConfig.cmake`.
- `ATHENA_OPENCV_PACKAGE_DIR` must point at an explicit OpenCV package prefix
  under `build/deps/<target>/opencv` containing `OpenCVConfig.cmake`.
- Do not rely on `/usr/lib`, `/usr/include`, host OpenCV, host protobuf, host
  libusb, or untracked local package installs for release artifacts.
- `third_party/` is reserved for source dependencies such as `godot-cpp`, not
  random local binary builds.

## Dependency Provisioning

Pinned dependency versions live in `cmake/deps/versions.cmake`.

Provision the real production dependencies before configuring the plugin:

```sh
./scripts/provision-deps.sh linux-x86_64
./scripts/provision-deps.sh debian12-aarch64
```

The script installs only under:

- `build/deps/linux-x86_64/`
- `build/deps/debian12-aarch64/`

Normal plugin CMake configure never downloads or builds dependencies. It only
consumes the explicit prefixes created by provisioning. `linux-x86_64`
provisioning must run inside a Debian 12-compatible environment; on a host with
glibc newer than `2.36`, the script refuses to build release dependencies.

## Development Workflow

Host development builds still use the same explicit provisioned prefixes. On a
Debian 12-compatible host:

```sh
./scripts/provision-deps.sh linux-x86_64
./scripts/build-plugin.sh linux-x86_64-dev
```

On an Arch or other newer-glibc host, dependency provisioning for release
profiles refuses to run directly. Use the Debian 12 container workflow below.

## Release Workflow

Build release artifacts inside the Debian 12 container:

```sh
./scripts/build-in-debian12.sh linux-x86_64-release
```

The script auto-detects Podman or Docker, builds
`ci/debian12/Dockerfile`, mounts the workspace at the same absolute path, then
runs:

```sh
./scripts/provision-deps.sh linux-x86_64
cmake --fresh --preset linux-x86_64-release
cmake --build --preset linux-x86_64-release --parallel <jobs>
cmake --build --preset check-abi-linux-x86_64-release --parallel <jobs>
cmake --build --preset package-runtime --parallel <jobs>
```

To build and deploy the packaged addon into an existing Godot project in one
step:

```sh
./scripts/build-in-debian12.sh linux-x86_64-release --deploy /path/to/godot-project
```

ARM64 release builds use the same wrapper after the Debian 12 ARM64 sysroot is
available:

```sh
./tools/bootstrap-debian12-sysroot.sh
./scripts/build-in-debian12.sh debian12-aarch64-release
```

Expected plugin artifacts:

- `project/bin/libathena_godot.so`
- `project/bin/libathena_plugin.so`
- `dist/x86_64/athena-runtime/addons/athena/athena.gdextension`
- `dist/x86_64/athena-runtime/addons/athena/bin/linux.x86_64/libathena_godot.so`
- `dist/x86_64/athena-runtime/addons/athena/bin/linux.x86_64/libathena_plugin.so`
- `project/bin/linux-arm64/libathena_godot.so`
- `project/bin/linux-arm64/libathena_plugin.so`

The `dist/x86_64/athena-runtime/` directory is the self-contained Linux x86_64
Godot runtime package. It uses the expected addon layout:

```text
dist/x86_64/athena-runtime/
└── addons/
    └── athena/
        ├── athena.gdextension
        └── bin/
            └── linux.x86_64/
                ├── libathena_godot.so
                ├── libathena_plugin.so
                └── <bundled runtime .so files>
```

Runtime dependency bundling is explicit. The `package-runtime` target copies
the wrapper and native Athena plugin into
`dist/x86_64/athena-runtime/addons/athena/bin/linux.x86_64/`, installs a
rewritten `athena.gdextension` manifest, copies OpenCV runtime libraries from
`build/deps/linux-x86_64/opencv/lib/`, copies the provisioned DepthAI/XLink
`libusb-1.0.so` from `build/deps/linux-x86_64/depthai/`, rewrites the packaged
ELF runpaths to `$ORIGIN`, and verifies the packaged `libathena_plugin.so`
with `ldd`. The package check fails if OpenCV, libusb, or DepthAI runtime
dependencies are unresolved or still resolve from `build/deps/`. Bundled
libraries are resolved from the same `bin/linux.x86_64/` directory instead of
from host `/usr`.

## Deployment

Deploy an already packaged addon into a Godot project with:

```sh
scripts/deploy.sh /path/to/godot-project
```

The deploy script validates that the destination contains `project.godot`, then
uses `rsync --delete` to replace only `addons/athena/`. Re-running the command
updates changed files and removes stale files from previous deployments.

## Presets

`linux-x86_64-dev` builds a Debug x86_64 GDExtension for local development:

```sh
./scripts/provision-deps.sh linux-x86_64
./scripts/build-plugin.sh linux-x86_64-dev
```

`linux-x86_64-release` builds a Release x86_64 GDExtension:

```sh
./scripts/provision-deps.sh linux-x86_64
./scripts/build-plugin.sh linux-x86_64-release
cmake --build --preset package-runtime
```

`debian12-aarch64-release` builds a Release ARM64 GDExtension with the Debian
12 ARM64 toolchain file. Create the base sysroot first:

```sh
./tools/bootstrap-debian12-sysroot.sh
./scripts/provision-deps.sh debian12-aarch64
./scripts/build-plugin.sh debian12-aarch64-release
```

Debian 12 is the maximum runtime ABI target. Release artifacts should be built
inside a Debian 12 container/sysroot or with a Debian 12-compatible toolchain
and dependency set.

## ABI Validation

The build adds a `check-abi` target and the standalone
`scripts/check-abi.sh` helper. The check runs `readelf -Ws`, `objdump -T`, and
`ldd -v` on the produced wrapper and native plugin libraries. It fails if
`GLIBC_PRIVATE` appears, fails if a configured target requires symbols newer
than Debian 12's `GLIBC_2.36`, and reports required `GLIBC_` symbol versions.

```sh
cmake --build --preset check-abi-linux-x86_64-release
cmake --build --preset check-abi-debian12-aarch64-release
```

For cross-built ARM64 libraries, run the standalone script inside a compatible
ARM64 environment or container when host `ldd` cannot load the target binary.
