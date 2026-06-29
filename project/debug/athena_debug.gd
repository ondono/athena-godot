extends Control

const RGB_STREAM := 0

var device
var last_rgb_sequence := -1

var status_label: Label
var abi_label: Label
var imu_label: Label
var rgb_label: Label
var tag_label: Label
var rgb_preview: TextureRect


func _ready() -> void:
    _build_ui()

    device = ClassDB.instantiate("AthenaDevice")
    if device == null:
        status_label.text = "AthenaDevice class unavailable; check GDExtension load"
        return

    device.name = "AthenaDevice"
    device.allow_simulated_fallback = false
    device.enable_rgb = true
    device.enable_ir = true
    device.enable_thermal = false
    add_child(device)

    var initialized = device.initialize()
    status_label.text = "initialize=%s ping=%d" % [str(initialized), device.ping()]
    abi_label.text = _format_abi(device.get_abi_info())


func _exit_tree() -> void:
    if device != null:
        device.shutdown()


func _process(_delta: float) -> void:
    if device == null:
        return

    var status = device.get_status()
    var imu = device.get_latest_imu()
    var rgb = device.get_frame_metadata(RGB_STREAM)
    var tags = device.get_apriltags(8)

    status_label.text = _format_status(status)
    imu_label.text = _format_imu(imu)
    rgb_label.text = _format_rgb(rgb)
    tag_label.text = _format_tags(tags)

    if rgb.get("available", false):
        var sequence := int(rgb.get("sequence", -1))
        if sequence != last_rgb_sequence:
            var texture = device.get_rgb_texture()
            if texture != null:
                rgb_preview.texture = texture
                last_rgb_sequence = sequence


func _build_ui() -> void:
    var root := VBoxContainer.new()
    root.set_anchors_preset(Control.PRESET_FULL_RECT)
    root.add_theme_constant_override("separation", 8)
    add_child(root)

    status_label = Label.new()
    status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    root.add_child(status_label)

    abi_label = Label.new()
    abi_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    root.add_child(abi_label)

    imu_label = Label.new()
    imu_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    root.add_child(imu_label)

    rgb_label = Label.new()
    rgb_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    root.add_child(rgb_label)

    tag_label = Label.new()
    tag_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    root.add_child(tag_label)

    rgb_preview = TextureRect.new()
    rgb_preview.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
    rgb_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    rgb_preview.custom_minimum_size = Vector2(640, 360)
    root.add_child(rgb_preview)


func _format_status(status: Dictionary) -> String:
    if not status.get("available", false):
        return "status unavailable"

    return "status=%s simulated=%s depthai=%s mxid=\"%s\" error=\"%s\"" % [
        str(status.get("state_name", "unknown")),
        str(status.get("simulated", false)),
        str(status.get("depthai_enabled", false)),
        str(status.get("device_mxid", "")),
        str(status.get("error", "")),
    ]


func _format_abi(abi: Dictionary) -> String:
    return "abi=%s config=%s status=%s frame=%s tag=%s" % [
        str(abi.get("abi_version", "?")),
        str(abi.get("athena_config_size", "?")),
        str(abi.get("athena_status_size", "?")),
        str(abi.get("athena_frame_metadata_size", "?")),
        str(abi.get("athena_apriltag_detection_size", "?")),
    ]


func _format_imu(imu: Dictionary) -> String:
    if not imu.get("available", false):
        return "imu unavailable"

    return "imu t=%.2f q=(%.3f, %.3f, %.3f, %.3f) accel=(%.3f, %.3f, %.3f) gyro=(%.3f, %.3f, %.3f)" % [
        float(imu.get("timestamp_ms", 0.0)),
        float(imu.get("qx", 0.0)),
        float(imu.get("qy", 0.0)),
        float(imu.get("qz", 0.0)),
        float(imu.get("qw", 0.0)),
        float(imu.get("ax", 0.0)),
        float(imu.get("ay", 0.0)),
        float(imu.get("az", 0.0)),
        float(imu.get("gx", 0.0)),
        float(imu.get("gy", 0.0)),
        float(imu.get("gz", 0.0)),
    ]


func _format_rgb(rgb: Dictionary) -> String:
    if not rgb.get("available", false):
        return "rgb unavailable"

    return "rgb %sx%s format=%s bytes=%s seq=%s t=%.2f" % [
        str(rgb.get("width", 0)),
        str(rgb.get("height", 0)),
        str(rgb.get("pixel_format_name", "unknown")),
        str(rgb.get("bytes_required", 0)),
        str(rgb.get("sequence", 0)),
        float(rgb.get("timestamp_ms", 0.0)),
    ]


func _format_tags(tags: Array) -> String:
    if tags.is_empty():
        return "apriltags count=0"

    var first: Dictionary = tags[0]
    return "apriltags count=%d first_id=%s pose_valid=%s camera_cm=(%.2f, %.2f, %.2f)" % [
        tags.size(),
        str(first.get("id", "?")),
        str(first.get("pose_valid", false)),
        float(first.get("camera_unity_x_cm", 0.0)),
        float(first.get("camera_unity_y_cm", 0.0)),
        float(first.get("camera_unity_z_cm", 0.0)),
    ]
