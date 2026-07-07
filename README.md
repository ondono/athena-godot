# Athena Godot Plugin

This project is the Godot GDExtension counterpart to the native Athena plugin in
`/home/xavi/projects/inmersia/software/athena-plugin`.

The goal is to make Luxonis OAK devices usable from Godot while preserving the
native runtime model already used by the Unity plugin: one C++ worker thread, a
small polling API, and real DepthAI/OpenCV hardware support.

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

Build profiles are defined in `CMakePresets.json` and documented in
`BUILD.md`. The wrapper script is intentionally thin:

```sh
./scripts/build-plugin.sh linux-x86_64-release
```

Run `tools/bootstrap-godot-cpp.sh` before configuring if
`third_party/godot-cpp` is not present. Real DepthAI and OpenCV package roots
must be passed explicitly; the build does not silently use host packages.

The compiled library is emitted to `project/bin/` with a name matching
`project/bin/athena_godot.gdextension`.

To assemble the x86_64 release library and its runtime dependencies as a
reusable Godot addon:

```sh
cmake --build --preset package-runtime
```

The artifact is written to `dist/x86_64/athena-runtime/`. The packaged manifest
points to `res://addons/athena/bin/linux.x86_64`, and the package target checks
that OpenCV, libusb, and DepthAI runtime dependencies resolve from the packaged
addon instead of the build dependency tree.

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
./scripts/test-headless-hardware.sh
./scripts/test-headless-hardware.sh --timeout=30
```

The test disables simulated fallback and exits successfully only after the
GDExtension loads, the real DepthAI backend reaches `streaming`, IMU data is
available, and a complete RGB frame can be copied. It prints diagnostics to
standard output and returns a nonzero exit code on failure.

## Rock Pi 5+

Rock Pi 5+ should use the Linux ARM64 GDExtension entries in
`project/bin/athena_godot.gdextension`. Use the Debian 12 ARM64 release preset:

```sh
./tools/bootstrap-debian12-sysroot.sh
./scripts/provision-deps.sh debian12-aarch64
./scripts/build-rockpi-plugin.sh
```

## Source-Of-Truth Rules

- Reuse the native Athena ABI and backend behavior instead of inventing a
  separate Godot-only hardware path.
- Keep coordinate-frame and fixed camera-mount corrections in native Athena
  output so Unity and Godot see the same semantics.
- Keep Linux hardware and Windows packaging paths distinct.
- Prefer reproducible dependency metadata and bootstrap scripts when adding
  DepthAI/OpenCV/godot-cpp setup.
