extends Control

const STREAMS := [
    {"id": 0, "title": "RGB"},
    {"id": 1, "title": "IR Left"},
    {"id": 2, "title": "IR Right"},
    {"id": 3, "title": "Thermal Left"},
    {"id": 4, "title": "Thermal Right"},
]

var device
var stream_views := {}

var status_label: Label
var imu_label: Label
var tag_label: Label
var abi_label: Label


func _ready() -> void:
    _build_ui()
    _start_device()


func _exit_tree() -> void:
    if device != null:
        device.shutdown()


func _process(_delta: float) -> void:
    if device == null:
        return

    var status: Dictionary = device.get_status()
    var imu: Dictionary = device.get_latest_imu()
    var tags: Array = device.get_apriltags(8)

    status_label.text = _format_status(status)
    imu_label.text = _format_imu(imu)
    tag_label.text = _format_tags(tags)

    for stream in STREAMS:
        _update_stream(stream["id"])


func _start_device() -> void:
    device = ClassDB.instantiate("AthenaDevice")
    if device == null:
        status_label.text = "AthenaDevice class unavailable; run the Godot import step and check the GDExtension."
        return

    device.name = "AthenaDevice"
    device.allow_simulated_fallback = false
    device.enable_rgb = true
    device.enable_ir = true
    device.enable_thermal = false
    add_child(device)

    var initialized: bool = device.initialize()
    status_label.text = "initialize=%s ping=%d" % [str(initialized), device.ping()]
    abi_label.text = _format_abi(device.get_abi_info())


func _build_ui() -> void:
    var root := VBoxContainer.new()
    root.set_anchors_preset(Control.PRESET_FULL_RECT)
    root.add_theme_constant_override("separation", 8)
    add_child(root)

    var header := VBoxContainer.new()
    header.add_theme_constant_override("separation", 4)
    root.add_child(header)

    status_label = _make_label()
    header.add_child(status_label)

    abi_label = _make_label()
    header.add_child(abi_label)

    imu_label = _make_label()
    header.add_child(imu_label)

    tag_label = _make_label()
    header.add_child(tag_label)

    var scroll := ScrollContainer.new()
    scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    root.add_child(scroll)

    var grid := GridContainer.new()
    grid.columns = 2
    grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    grid.add_theme_constant_override("h_separation", 10)
    grid.add_theme_constant_override("v_separation", 10)
    scroll.add_child(grid)

    for stream in STREAMS:
        var panel := _make_stream_panel(stream["title"])
        grid.add_child(panel["root"])
        stream_views[stream["id"]] = panel


func _make_stream_panel(title: String) -> Dictionary:
    var root := PanelContainer.new()
    root.custom_minimum_size = Vector2(480, 360)
    root.size_flags_horizontal = Control.SIZE_EXPAND_FILL

    var box := VBoxContainer.new()
    box.add_theme_constant_override("separation", 6)
    root.add_child(box)

    var title_label := Label.new()
    title_label.text = title
    box.add_child(title_label)

    var meta_label := _make_label()
    box.add_child(meta_label)

    var texture_rect := TextureRect.new()
    texture_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
    texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    texture_rect.custom_minimum_size = Vector2(456, 256)
    texture_rect.size_flags_vertical = Control.SIZE_EXPAND_FILL
    box.add_child(texture_rect)

    return {
        "root": root,
        "meta": meta_label,
        "preview": texture_rect,
        "last_sequence": -1,
    }


func _make_label() -> Label:
    var label := Label.new()
    label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    return label


func _update_stream(stream_id: int) -> void:
    var view: Dictionary = stream_views[stream_id]
    var metadata: Dictionary = device.get_frame_metadata(stream_id)
    view["meta"].text = _format_stream(metadata)

    if not metadata.get("available", false):
        return

    var sequence := int(metadata.get("sequence", -1))
    if sequence == int(view["last_sequence"]):
        return

    var texture := _make_texture(stream_id, metadata)
    if texture == null:
        return

    view["preview"].texture = texture
    view["last_sequence"] = sequence


func _make_texture(stream_id: int, metadata: Dictionary) -> ImageTexture:
    var width := int(metadata.get("width", 0))
    var height := int(metadata.get("height", 0))
    var pixel_format := int(metadata.get("pixel_format", 0))
    if width <= 0 or height <= 0:
        return null

    var bytes: PackedByteArray = device.copy_frame_bytes(stream_id)
    if bytes.is_empty():
        return null

    var image_format := Image.FORMAT_MAX
    if pixel_format == 1:
        image_format = Image.FORMAT_RGB8
    elif pixel_format == 2:
        image_format = Image.FORMAT_L8
    else:
        return null

    var image := Image.create_from_data(width, height, false, image_format, bytes)
    return ImageTexture.create_from_image(image)


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


func _format_tags(tags: Array) -> String:
    if tags.is_empty():
        return "apriltags count=0"

    var first: Dictionary = tags[0]
    return "apriltags count=%d first_id=%s pose_valid=%s reproj=%.2f camera_cm=(%.2f, %.2f, %.2f)" % [
        tags.size(),
        str(first.get("id", "?")),
        str(first.get("pose_valid", false)),
        float(first.get("reprojection_error_px", 0.0)),
        float(first.get("camera_unity_x_cm", 0.0)),
        float(first.get("camera_unity_y_cm", 0.0)),
        float(first.get("camera_unity_z_cm", 0.0)),
    ]


func _format_stream(metadata: Dictionary) -> String:
    if not metadata.get("available", false):
        return "unavailable"

    return "%sx%s %s bytes=%s seq=%s t=%.2f" % [
        str(metadata.get("width", 0)),
        str(metadata.get("height", 0)),
        str(metadata.get("pixel_format_name", "unknown")),
        str(metadata.get("bytes_required", 0)),
        str(metadata.get("sequence", 0)),
        float(metadata.get("timestamp_ms", 0.0)),
    ]
