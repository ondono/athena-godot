#include "athena_godot/athena_device.h"

#include <algorithm>
#include <cstring>

#include <godot_cpp/classes/image.hpp>
#include <godot_cpp/classes/image_texture.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/string.hpp>

namespace godot
{
namespace
{

constexpr int32_t kMaxStream = static_cast<int32_t>(ATHENA_STREAM_THERMAL_RIGHT);

AthenaStream ToStream(int32_t stream)
{
    if (stream < 0 || stream > kMaxStream)
    {
        return ATHENA_STREAM_RGB;
    }
    return static_cast<AthenaStream>(stream);
}

String ConnectionStateName(AthenaConnectionState state)
{
    switch (state)
    {
    case ATHENA_CONNECTION_UNINITIALIZED:
        return "uninitialized";
    case ATHENA_CONNECTION_CONNECTING:
        return "connecting";
    case ATHENA_CONNECTION_STREAMING:
        return "streaming";
    case ATHENA_CONNECTION_DISCONNECTED:
        return "disconnected";
    case ATHENA_CONNECTION_ERROR:
        return "error";
    default:
        return "unknown";
    }
}

String PixelFormatName(AthenaPixelFormat format)
{
    switch (format)
    {
    case ATHENA_PIXEL_FORMAT_RGB24:
        return "rgb24";
    case ATHENA_PIXEL_FORMAT_R8:
        return "r8";
    case ATHENA_PIXEL_FORMAT_UNKNOWN:
    default:
        return "unknown";
    }
}

Dictionary FrameMetadataToDictionary(const AthenaFrameMetadata& metadata, bool available)
{
    Dictionary result;
    result["available"] = available;
    result["stream"] = static_cast<int32_t>(metadata.stream);
    result["pixel_format"] = static_cast<int32_t>(metadata.pixel_format);
    result["pixel_format_name"] = PixelFormatName(metadata.pixel_format);
    result["width"] = metadata.width;
    result["height"] = metadata.height;
    result["stride_bytes"] = metadata.stride_bytes;
    result["bytes_per_pixel"] = metadata.bytes_per_pixel;
    result["bytes_required"] = metadata.bytes_required;
    result["sequence"] = static_cast<int64_t>(metadata.sequence);
    result["timestamp_ms"] = metadata.timestamp_ms;
    return result;
}

void CopyStringToBuffer(const String& value, char* buffer, size_t buffer_size)
{
    if (buffer == nullptr || buffer_size == 0)
    {
        return;
    }

    const CharString utf8 = value.utf8();
    const size_t bytes_to_copy =
        std::min(buffer_size - 1, static_cast<size_t>(utf8.length()));
    std::memcpy(buffer, utf8.get_data(), bytes_to_copy);
    buffer[bytes_to_copy] = '\0';
}

} // namespace

void AthenaDevice::_bind_methods()
{
    ClassDB::bind_method(D_METHOD("initialize"), &AthenaDevice::initialize);
    ClassDB::bind_method(D_METHOD("shutdown"), &AthenaDevice::shutdown);
    ClassDB::bind_method(D_METHOD("ping"), &AthenaDevice::ping);
    ClassDB::bind_method(D_METHOD("get_abi_info"), &AthenaDevice::get_abi_info);
    ClassDB::bind_method(D_METHOD("get_status"), &AthenaDevice::get_status);
    ClassDB::bind_method(D_METHOD("get_connection_state_name"),
                         &AthenaDevice::get_connection_state_name);
    ClassDB::bind_method(D_METHOD("get_latest_imu"), &AthenaDevice::get_latest_imu);
    ClassDB::bind_method(D_METHOD("get_frame_metadata", "stream"),
                         &AthenaDevice::get_frame_metadata);
    ClassDB::bind_method(D_METHOD("copy_frame_bytes", "stream"), &AthenaDevice::copy_frame_bytes);
    ClassDB::bind_method(D_METHOD("get_rgb_image"), &AthenaDevice::get_rgb_image);
    ClassDB::bind_method(D_METHOD("get_rgb_texture"), &AthenaDevice::get_rgb_texture);
    ClassDB::bind_method(D_METHOD("get_apriltags", "max_count"), &AthenaDevice::get_apriltags);

    ClassDB::bind_method(D_METHOD("set_device_mxid", "device_mxid"),
                         &AthenaDevice::set_device_mxid);
    ClassDB::bind_method(D_METHOD("get_device_mxid"), &AthenaDevice::get_device_mxid);
    ClassDB::bind_method(D_METHOD("set_allow_simulated_fallback", "allow_simulated_fallback"),
                         &AthenaDevice::set_allow_simulated_fallback);
    ClassDB::bind_method(D_METHOD("get_allow_simulated_fallback"),
                         &AthenaDevice::get_allow_simulated_fallback);
    ClassDB::bind_method(D_METHOD("set_enable_rgb", "enable_rgb"), &AthenaDevice::set_enable_rgb);
    ClassDB::bind_method(D_METHOD("get_enable_rgb"), &AthenaDevice::get_enable_rgb);
    ClassDB::bind_method(D_METHOD("set_enable_ir", "enable_ir"), &AthenaDevice::set_enable_ir);
    ClassDB::bind_method(D_METHOD("get_enable_ir"), &AthenaDevice::get_enable_ir);
    ClassDB::bind_method(D_METHOD("set_enable_thermal", "enable_thermal"),
                         &AthenaDevice::set_enable_thermal);
    ClassDB::bind_method(D_METHOD("get_enable_thermal"), &AthenaDevice::get_enable_thermal);

    ADD_PROPERTY(PropertyInfo(Variant::STRING, "device_mxid"), "set_device_mxid",
                 "get_device_mxid");
    ADD_PROPERTY(PropertyInfo(Variant::BOOL, "allow_simulated_fallback"),
                 "set_allow_simulated_fallback", "get_allow_simulated_fallback");
    ADD_PROPERTY(PropertyInfo(Variant::BOOL, "enable_rgb"), "set_enable_rgb", "get_enable_rgb");
    ADD_PROPERTY(PropertyInfo(Variant::BOOL, "enable_ir"), "set_enable_ir", "get_enable_ir");
    ADD_PROPERTY(PropertyInfo(Variant::BOOL, "enable_thermal"), "set_enable_thermal",
                 "get_enable_thermal");

    BIND_ENUM_CONSTANT(STREAM_RGB);
    BIND_ENUM_CONSTANT(STREAM_IR_LEFT);
    BIND_ENUM_CONSTANT(STREAM_IR_RIGHT);
    BIND_ENUM_CONSTANT(STREAM_THERMAL_LEFT);
    BIND_ENUM_CONSTANT(STREAM_THERMAL_RIGHT);
}

AthenaDevice::~AthenaDevice()
{
    if (initialized_)
    {
        shutdown();
    }
}

bool AthenaDevice::initialize()
{
    if (initialized_)
    {
        return true;
    }

    const AthenaConfig config = make_config();
    initialized_ = Athena_InitializeWithConfigSized(&config, sizeof(config));
    return initialized_;
}

void AthenaDevice::shutdown()
{
    Athena_Shutdown();
    initialized_ = false;
}

int32_t AthenaDevice::ping() const
{
    return Athena_Ping();
}

Dictionary AthenaDevice::get_abi_info() const
{
    AthenaAbiInfo info{};
    Athena_GetAbiInfo(&info);

    Dictionary result;
    result["abi_version"] = info.abi_version;
    result["athena_config_size"] = info.athena_config_size;
    result["athena_status_size"] = info.athena_status_size;
    result["athena_frame_metadata_size"] = info.athena_frame_metadata_size;
    result["athena_apriltag_detection_size"] = info.athena_apriltag_detection_size;
    return result;
}

Dictionary AthenaDevice::get_status() const
{
    AthenaStatus status{};
    Dictionary result;
    if (!Athena_GetStatus(&status))
    {
        result["available"] = false;
        return result;
    }

    result["available"] = true;
    result["state"] = static_cast<int32_t>(status.state);
    result["state_name"] = ConnectionStateName(status.state);
    result["depthai_enabled"] = status.depthai_enabled != 0;
    result["simulated"] = status.simulated != 0;
    result["device_mxid"] = String(status.device_mxid);
    result["error"] = String(status.error);
    return result;
}

String AthenaDevice::get_connection_state_name() const
{
    AthenaStatus status{};
    if (!Athena_GetStatus(&status))
    {
        return "unavailable";
    }
    return ConnectionStateName(status.state);
}

Dictionary AthenaDevice::get_latest_imu() const
{
    ImuState imu{};
    Dictionary result;
    if (!Athena_GetLatestImuState(&imu))
    {
        result["available"] = false;
        return result;
    }

    result["available"] = true;
    result["qx"] = imu.qx;
    result["qy"] = imu.qy;
    result["qz"] = imu.qz;
    result["qw"] = imu.qw;
    result["ax"] = imu.ax;
    result["ay"] = imu.ay;
    result["az"] = imu.az;
    result["gx"] = imu.gx;
    result["gy"] = imu.gy;
    result["gz"] = imu.gz;
    result["mx"] = imu.mx;
    result["my"] = imu.my;
    result["mz"] = imu.mz;
    result["magnetometer_valid"] = imu.magnetometer_valid != 0;
    result["timestamp_ms"] = imu.timestamp_ms;
    return result;
}

Dictionary AthenaDevice::get_frame_metadata(int32_t stream) const
{
    AthenaFrameMetadata metadata{};
    const bool available = Athena_GetLatestFrameMetadata(ToStream(stream), &metadata);
    return FrameMetadataToDictionary(metadata, available);
}

PackedByteArray AthenaDevice::copy_frame_bytes(int32_t stream) const
{
    AthenaFrameMetadata metadata{};
    if (!Athena_GetLatestFrameMetadata(ToStream(stream), &metadata) ||
        metadata.bytes_required == 0)
    {
        return {};
    }

    PackedByteArray bytes;
    bytes.resize(static_cast<int64_t>(metadata.bytes_required));
    AthenaFrameMetadata copied_metadata{};
    if (!Athena_CopyLatestFrame(ToStream(stream), bytes.ptrw(), metadata.bytes_required,
                                &copied_metadata))
    {
        return {};
    }
    return bytes;
}

Ref<Image> AthenaDevice::get_rgb_image() const
{
    AthenaFrameMetadata metadata{};
    if (!Athena_GetLatestFrameMetadata(ATHENA_STREAM_RGB, &metadata) ||
        metadata.pixel_format != ATHENA_PIXEL_FORMAT_RGB24 || metadata.width == 0 ||
        metadata.height == 0 || metadata.bytes_required == 0)
    {
        return {};
    }

    PackedByteArray bytes;
    bytes.resize(static_cast<int64_t>(metadata.bytes_required));
    AthenaFrameMetadata copied_metadata{};
    if (!Athena_CopyLatestFrame(ATHENA_STREAM_RGB, bytes.ptrw(), metadata.bytes_required,
                                &copied_metadata))
    {
        return {};
    }

    return Image::create_from_data(static_cast<int32_t>(copied_metadata.width),
                                   static_cast<int32_t>(copied_metadata.height), false,
                                   Image::FORMAT_RGB8, bytes);
}

Ref<ImageTexture> AthenaDevice::get_rgb_texture() const
{
    const Ref<Image> image = get_rgb_image();
    if (image.is_null())
    {
        return {};
    }

    return ImageTexture::create_from_image(image);
}

Array AthenaDevice::get_apriltags(int32_t max_count) const
{
    Array result;
    if (max_count <= 0)
    {
        return result;
    }

    const uint32_t capacity = static_cast<uint32_t>(std::min(max_count, 64));
    Vector<AthenaAprilTagDetection> detections;
    detections.resize(static_cast<int64_t>(capacity));

    uint32_t detection_count = 0;
    double timestamp_ms = 0.0;
    if (!Athena_GetLatestAprilTagDetections(detections.ptrw(), capacity, &detection_count,
                                            &timestamp_ms))
    {
        return result;
    }

    for (uint32_t index = 0; index < detection_count; ++index)
    {
        const AthenaAprilTagDetection& tag = detections[static_cast<int64_t>(index)];
        Dictionary item;
        item["id"] = tag.id;
        item["timestamp_ms"] = timestamp_ms;
        item["center_x"] = tag.center_x;
        item["center_y"] = tag.center_y;
        item["corner_top_left_x"] = tag.corner_top_left_x;
        item["corner_top_left_y"] = tag.corner_top_left_y;
        item["corner_top_right_x"] = tag.corner_top_right_x;
        item["corner_top_right_y"] = tag.corner_top_right_y;
        item["corner_bottom_right_x"] = tag.corner_bottom_right_x;
        item["corner_bottom_right_y"] = tag.corner_bottom_right_y;
        item["corner_bottom_left_x"] = tag.corner_bottom_left_x;
        item["corner_bottom_left_y"] = tag.corner_bottom_left_y;
        item["pose_valid"] = tag.pose_valid != 0;
        item["pose_tx_m"] = tag.pose_tx_m;
        item["pose_ty_m"] = tag.pose_ty_m;
        item["pose_tz_m"] = tag.pose_tz_m;
        item["pose_qx"] = tag.pose_qx;
        item["pose_qy"] = tag.pose_qy;
        item["pose_qz"] = tag.pose_qz;
        item["pose_qw"] = tag.pose_qw;
        item["reprojection_error_px"] = tag.reprojection_error_px;
        item["camera_pose_valid"] = tag.camera_pose_valid != 0;
        item["detector_to_viewer_camera_applied"] = tag.detector_to_viewer_camera_applied != 0;
        item["camera_tx_m"] = tag.camera_tx_m;
        item["camera_ty_m"] = tag.camera_ty_m;
        item["camera_tz_m"] = tag.camera_tz_m;
        item["camera_qx"] = tag.camera_qx;
        item["camera_qy"] = tag.camera_qy;
        item["camera_qz"] = tag.camera_qz;
        item["camera_qw"] = tag.camera_qw;
        item["camera_unity_x_cm"] = tag.camera_unity_x_cm;
        item["camera_unity_y_cm"] = tag.camera_unity_y_cm;
        item["camera_unity_z_cm"] = tag.camera_unity_z_cm;
        result.append(item);
    }

    return result;
}

void AthenaDevice::set_device_mxid(const String& device_mxid)
{
    device_mxid_ = device_mxid;
}

String AthenaDevice::get_device_mxid() const
{
    return device_mxid_;
}

void AthenaDevice::set_allow_simulated_fallback(bool allow_simulated_fallback)
{
    allow_simulated_fallback_ = allow_simulated_fallback;
}

bool AthenaDevice::get_allow_simulated_fallback() const
{
    return allow_simulated_fallback_;
}

void AthenaDevice::set_enable_rgb(bool enable_rgb)
{
    enable_rgb_ = enable_rgb;
}

bool AthenaDevice::get_enable_rgb() const
{
    return enable_rgb_;
}

void AthenaDevice::set_enable_ir(bool enable_ir)
{
    enable_ir_ = enable_ir;
}

bool AthenaDevice::get_enable_ir() const
{
    return enable_ir_;
}

void AthenaDevice::set_enable_thermal(bool enable_thermal)
{
    enable_thermal_ = enable_thermal;
}

bool AthenaDevice::get_enable_thermal() const
{
    return enable_thermal_;
}

AthenaConfig AthenaDevice::make_config() const
{
    AthenaConfig config{};
    Athena_GetDefaultConfigSized(&config, sizeof(config));

    CopyStringToBuffer(device_mxid_, config.device_mxid, sizeof(config.device_mxid));
    config.allow_simulated_fallback = allow_simulated_fallback_ ? 1U : 0U;
    config.enable_rgb = enable_rgb_ ? 1U : 0U;
    config.enable_ir = enable_ir_ ? 1U : 0U;
    config.enable_thermal = enable_thermal_ ? 1U : 0U;

    return config;
}

} // namespace godot
