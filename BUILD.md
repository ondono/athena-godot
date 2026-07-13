# Build And Deploy

This repo builds the Godot GDExtension wrapper around the real native Athena
plugin at `/home/xavi/projects/inmersia/software/athena-plugin`.

The supported presets are hardware-capable builds. Simulated, no-camera, and
no-DepthAI builds are not production profiles here.

## Source Layout

- Wrapper repo: `/home/xavi/projects/inmersia/godot/athena-plugin-godot`
- Native plugin repo: `/home/xavi/projects/inmersia/software/athena-plugin`
- App repo: `/home/xavi/projects/inmersia/godot/athena-app-godot`
- Packaged Athena addon output:
  `dist/x86_64/athena-runtime/addons/athena`
- App install destination:
  `/home/xavi/projects/inmersia/godot/athena-app-godot/addons/athena`

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

Pinned dependency versions live in `cmake/deps/versions.cmake`.

## Build And Deploy To athena-app-godot

Use this sequence when the goal is to build the x86_64 Athena Godot plugin and
deploy it into the app checkout.

1. From this repo:

```sh
cd /home/xavi/projects/inmersia/godot/athena-plugin-godot
```

2. Build the Debian 12-compatible x86_64 release package:

```sh
./scripts/build-in-debian12.sh linux-x86_64-release
```

This command builds the Debian 12 container image, provisions pinned
dependencies under `build/deps/linux-x86_64/`, configures the
`linux-x86_64-release` preset, checks the Debian 12 ABI ceiling, and creates the
self-contained addon package at:

```text
dist/x86_64/athena-runtime/addons/athena/
```

3. Deploy the packaged Athena addon into `athena-app-godot`:

```sh
./scripts/deploy.sh /home/xavi/projects/inmersia/godot/athena-app-godot
```

This replaces only:

```text
/home/xavi/projects/inmersia/godot/athena-app-godot/addons/athena/
```

It does not install or rebuild MBTiles. The app's `addons/mbtiles/` package is
owned by `athena-app-godot`.

4. Validate the app runtime from the app repo:

```sh
cd /home/xavi/projects/inmersia/godot/athena-app-godot
./scripts/validate-runtime.sh linux-x86_64
```

`validate-runtime.sh` checks both `addons/athena` and `addons/mbtiles`. If it
fails because MBTiles is missing, fix the MBTiles package in the app repo; do
not add MBTiles binaries to this wrapper repo.

5. Run the app/editor from the app repo:

```sh
./scripts/run-editor.sh
```

or:

```sh
./scripts/run-app.sh
```

## One-Step Build And Deploy

For the same x86_64 release flow, this wrapper can deploy after the container
build finishes:

```sh
cd /home/xavi/projects/inmersia/godot/athena-plugin-godot
./scripts/build-in-debian12.sh linux-x86_64-release --deploy /home/xavi/projects/inmersia/godot/athena-app-godot
```

The container creates the package. Deployment then runs on the host, because
the app checkout is a host path.

## Package Layout

The Linux x86_64 runtime package is:

```text
dist/x86_64/athena-runtime/
└── addons/
    └── athena/
        ├── athena.gdextension
        └── bin/
            └── linux.x86_64/
                ├── libathena_godot.so
                ├── libathena_plugin.so
                ├── libopencv_*.so*
                └── libusb-1.0.so
```

Runtime dependency bundling is explicit. The `package-runtime` target copies
the wrapper and native Athena plugin, copies OpenCV runtime libraries from
`build/deps/linux_x86_64/opencv/lib/`, copies the provisioned DepthAI/XLink
`libusb-1.0.so`, rewrites packaged ELF runpaths to `$ORIGIN`, and verifies the
packaged `libathena_plugin.so` with `ldd`.

The package check fails if OpenCV, libusb, or DepthAI runtime dependencies are
unresolved or still resolve from `build/deps/`.

## Development Build

For local development on a Debian 12-compatible host:

```sh
cd /home/xavi/projects/inmersia/godot/athena-plugin-godot
./scripts/provision-deps.sh linux-x86_64
./scripts/build-plugin.sh linux-x86_64-dev
```

The development build writes directly to:

```text
project/bin/
```

The build stages the runtime libraries needed by the local test project next to
`project/bin/libathena_godot.so`.

On Arch or another newer-glibc host, do not use a host release build as the app
runtime. It can load locally but will fail the Debian 12 `GLIBC_2.36` ABI gate.
Use `./scripts/build-in-debian12.sh linux-x86_64-release` for deployable app
artifacts.

## ARM64 Release

ARM64 release builds target Debian 12 aarch64. Create the base sysroot first:

```sh
cd /home/xavi/projects/inmersia/godot/athena-plugin-godot
./tools/bootstrap-debian12-sysroot.sh
./scripts/build-in-debian12.sh debian12-aarch64-release
```

Expected ARM64 wrapper artifacts:

```text
project/bin/linux-arm64/libathena_godot.so
project/bin/linux-arm64/libathena_plugin.so
```

The x86_64 `--deploy` flow is the supported app deploy path here. ARM64 app or
Rock Pi deployment should be handled by the app repo's target-specific
packaging/deploy scripts.

## Manual Preset Commands

The container workflow runs the following x86_64 release steps for you:

```sh
./scripts/provision-deps.sh linux-x86_64
cmake --fresh --preset linux-x86_64-release
cmake --build --preset linux-x86_64-release --parallel <jobs>
cmake --build --preset check-abi-linux-x86_64-release --parallel <jobs>
cmake --build --preset package-runtime --parallel <jobs>
```

Use the manual commands only when you intentionally control the build
environment. On a newer-glibc host, the ABI check is expected to fail for
release artifacts.

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
