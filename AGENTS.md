# Repository Guidance

This repo is for the Godot GDExtension wrapper around the native Athena plugin.

## Source Of Truth

- Native runtime behavior lives in
  `/home/xavi/projects/inmersia/software/athena-plugin`.
- Before changing ABI assumptions, inspect
  `/home/xavi/projects/inmersia/software/athena-plugin/include/athena_plugin/athena_plugin.h`.
- Do not reimplement DepthAI, OpenCV, worker-thread, frame-buffer, or AprilTag
  semantics in this repo unless the native plugin explicitly lacks the required
  behavior.

## Godot Shape

- Use `godot-cpp` and a `.gdextension` manifest.
- Keep Godot classes thin and scene-editable. Prefer a visible `AthenaDevice`
  node over hidden bootstrap state.
- Translate native Athena data into Godot-friendly types at the boundary:
  `Dictionary`, `PackedByteArray`, `Image`, `ImageTexture`, `Transform3D`, or
  typed `Resource` classes where useful.
- Keep the native plugin's polling model as the default path. Add signals only
  as convenience notifications.

## Build And Validation

- Validate local context before diagnosing build/load problems.
- Keep simulated/no-DepthAI validation separate from real hardware/DepthAI
  validation.
- For native Athena dependency setup, prefer a checked-in manifest plus
  bootstrap scripts over ad hoc setup notes.
- Do not assume `.git` is valid in this checkout; it currently exists only as an
  empty placeholder directory.
