extends SceneTree

const RGB_STREAM := 0
const DEFAULT_TIMEOUT_SECONDS := 20.0
const POLL_INTERVAL_SECONDS := 0.1

var device


func _initialize() -> void:
    call_deferred("_run")


func _finalize() -> void:
    if device != null:
        device.shutdown()


func _run() -> void:
    var timeout_seconds := _get_timeout_seconds()
    print("Athena headless hardware smoke test (timeout %.1fs)" % timeout_seconds)

    if not ClassDB.class_exists("AthenaDevice"):
        _fail(10, "AthenaDevice is not registered; the GDExtension did not load")
        return

    device = ClassDB.instantiate("AthenaDevice")
    if device == null:
        _fail(11, "AthenaDevice could not be instantiated")
        return

    device.allow_simulated_fallback = false
    device.enable_rgb = true
    device.enable_ir = true
    device.enable_thermal = false
    get_root().add_child(device)

    var ping: int = device.ping()
    var abi: Dictionary = device.get_abi_info()
    print("Plugin loaded: ping=%d abi=%s" % [ping, str(abi)])
    if ping <= 0:
        _fail(12, "native plugin ping failed")
        return
    if not device.initialize():
        _fail(13, "AthenaDevice.initialize() failed")
        return

    var started_ms := Time.get_ticks_msec()
    var last_state := ""
    while float(Time.get_ticks_msec() - started_ms) / 1000.0 < timeout_seconds:
        var status: Dictionary = device.get_status()
        var state := str(status.get("state_name", "unavailable"))
        if state != last_state:
            print("Connection state: %s mxid=\"%s\" error=\"%s\"" % [
                state,
                str(status.get("device_mxid", "")),
                str(status.get("error", "")),
            ])
            last_state = state

        if status.get("simulated", false):
            _fail(14, "plugin entered simulated mode")
            return
        if status.get("available", false) and not status.get("depthai_enabled", false):
            _fail(15, "plugin was built without DepthAI support")
            return
        if state == "error" or state == "disconnected":
            _fail(16, "device connection failed: %s" % str(status.get("error", state)))
            return

        var imu: Dictionary = device.get_latest_imu()
        var rgb: Dictionary = device.get_frame_metadata(RGB_STREAM)
        if state == "streaming" and imu.get("available", false) and rgb.get("available", false):
            var frame: PackedByteArray = device.copy_frame_bytes(RGB_STREAM)
            var expected_bytes := int(rgb.get("bytes_required", 0))
            if expected_bytes <= 0 or frame.size() != expected_bytes:
                _fail(17, "RGB frame copy failed: expected %d bytes, got %d" % [
                    expected_bytes,
                    frame.size(),
                ])
                return

            print("PASS: real device streaming; mxid=%s" % str(status.get("device_mxid", "")))
            print("IMU: timestamp_ms=%.2f accel=(%.3f, %.3f, %.3f)" % [
                float(imu.get("timestamp_ms", 0.0)),
                float(imu.get("ax", 0.0)),
                float(imu.get("ay", 0.0)),
                float(imu.get("az", 0.0)),
            ])
            print("RGB: %dx%d %s sequence=%d bytes=%d" % [
                int(rgb.get("width", 0)),
                int(rgb.get("height", 0)),
                str(rgb.get("pixel_format_name", "unknown")),
                int(rgb.get("sequence", 0)),
                frame.size(),
            ])
            device.shutdown()
            device = null
            quit(0)
            return

        await create_timer(POLL_INTERVAL_SECONDS).timeout

    var final_status: Dictionary = device.get_status()
    _fail(18, "timed out waiting for streaming, IMU, and RGB: %s" % str(final_status))


func _get_timeout_seconds() -> float:
    for argument in OS.get_cmdline_user_args():
        if argument.begins_with("--timeout="):
            return maxf(float(argument.trim_prefix("--timeout=")), 1.0)
    return DEFAULT_TIMEOUT_SECONDS


func _fail(exit_code: int, message: String) -> void:
    printerr("FAIL: %s" % message)
    if device != null:
        device.shutdown()
        device = null
    quit(exit_code)
