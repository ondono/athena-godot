# Athena Godot Plugin

This project is the Godot GDExtension counterpart to the native Athena plugin in
`/home/xavi/projects/inmersia/software/athena-plugin`.

The goal is to make Luxonis OAK devices usable from Godot while preserving the
native runtime model already used by the Unity plugin: one C++ worker thread, a
small polling API, deterministic simulated fallback, and optional DepthAI/OpenCV
hardware support.

## Architecture

- `src/register_types.cpp` is the GDExtension entry point. It registers Godot
  classes with the engine.
- `include/athena_godot/athena_device.h` and `src/athena_device.cpp` expose a
  Godot `Node` wrapper for the native Athena plugin lifecycle and polling API.
- `project/bin/athena_godot.gdextension` tells Godot which shared library to
  load for each platform.
- The runtime source of truth is still the native Athena plugin C ABI:
  `include/athena_plugin/athena_plugin.h` in the sibling source repo.

Godot integration should be thin. Device ownership, DepthAI/OpenCV setup,
threading, frame buffers, status, and AprilTag pose semantics belong in the
native Athena runtime. This repo should translate those results into Godot
types, resources, textures, nodes, and signals.

## Intended Public Surface

Start with one scene-editable node:

- `AthenaDevice`
  - `initialize() -> bool`
  - `shutdown()`
  - `ping() -> int`
  - `get_status() -> Dictionary`
  - `get_latest_imu() -> Dictionary`

Next expansion points:

- Frame polling into `Image`/`ImageTexture` for RGB, IR, and thermal streams.
- AprilTag detections as dictionaries or typed Godot resources.
- Optional signals for connection-state and frame-available notifications, while
  keeping polling as the core low-latency path.

## Dependencies

- Godot 4.x with GDExtension support.
- `godot-cpp` checked out at `third_party/godot-cpp`, or provided with
  `-DGODOT_CPP_DIR=/path/to/godot-cpp`.
- Native Athena plugin source at `../../software/athena-plugin`, or provided
  with `-DATHENA_NATIVE_PLUGIN_DIR=/path/to/athena-plugin`.

Godot documents GDExtension as native shared libraries loaded at runtime, with
`godot-cpp` as the standard C++ binding layer. The `.gdextension` file maps
platform tags to the shared library Godot should load.

## Build

This scaffold expects CMake and an existing `godot-cpp` checkout:

```sh
./build.sh
```

`tools/bootstrap-godot-cpp.sh` clones the matching `godot-cpp` branch when the
installed Godot major/minor branch exists. The local editor is Godot 4.7, and
upstream `godot-cpp` currently does not publish a `4.7` branch, so the script
falls back to `master` unless `GODOT_CPP_REF` is set.

The compiled library should be copied or emitted to `project/bin/` with a name
matching `project/bin/athena_godot.gdextension`.

To assemble the already-built x86_64 and ARM64 libraries as a reusable Godot
addon:

```sh
./tools/package-addon.sh
```

The artifact is written to `dist/athena-addon` by default. Set `OUTPUT_DIR` to
use another location. The packaged manifest points to
`res://addons/athena/bin`, and `SHA256SUMS` covers the manifest and native
libraries.

After a fresh checkout, open the Godot project once or run an import pass so
Godot writes its generated extension list:

```sh
godot --headless --path project --import
```

Then run the debug scene:

```sh
godot --path project
```

To test the extension and a connected Luxonis device without a display:

```sh
./headless-test.sh
./headless-test.sh --timeout=30
```

The test disables simulated fallback and exits successfully only after the
GDExtension loads, the real DepthAI backend reaches `streaming`, IMU data is
available, and a complete RGB frame can be copied. It prints diagnostics to
standard output and returns a nonzero exit code on failure.

## Rock Pi 5+

Rock Pi 5+ should use the Linux ARM64 GDExtension entries in
`project/bin/athena_godot.gdextension`. To build on the board itself:

```sh
./build-rockpi.sh
```

To cross-compile from x86_64, provide an ARM64 sysroot if the host does not
already have an aarch64 linker/runtime:

```sh
ATHENA_AARCH64_SYSROOT=/path/to/rockpi/sysroot ./build-rockpi.sh
```

On this Arch Linux host, a local Arch Linux ARM sysroot can be downloaded and
extracted with:

```sh
./tools/bootstrap-rockpi-sysroot.sh
ATHENA_AARCH64_SYSROOT="$PWD/build/sysroots/archlinuxarm-aarch64" \
ATHENA_AARCH64_TARGET=aarch64-unknown-linux-gnu \
./build-rockpi.sh
```

The default Rock Pi build is simulated/no-DepthAI so the Godot extension can be
compiled first. For real Luxonis hardware on the board, build or provide ARM64
DepthAI/OpenCV packages and run:

```sh
ATHENA_ENABLE_DEPTHAI=ON ATHENA_DEPTHAI_PACKAGE_DIR=/path/to/arm64/depthai ./build-rockpi.sh
```

## Source-Of-Truth Rules

- Reuse the native Athena ABI and backend behavior instead of inventing a
  separate Godot-only hardware path.
- Keep coordinate-frame and fixed camera-mount corrections in native Athena
  output so Unity and Godot see the same semantics.
- Keep Linux hardware, Linux simulated, and Windows packaging paths distinct.
- Prefer reproducible dependency metadata and bootstrap scripts when adding
  DepthAI/OpenCV/godot-cpp setup.
