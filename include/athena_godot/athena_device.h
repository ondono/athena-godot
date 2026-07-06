#pragma once

#include "athena_plugin/athena_plugin.h"

#include <godot_cpp/classes/image.hpp>
#include <godot_cpp/classes/image_texture.hpp>
#include <godot_cpp/classes/node.hpp>
#include <godot_cpp/core/object.hpp>
#include <godot_cpp/templates/vector.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_byte_array.hpp>
#include <godot_cpp/variant/string.hpp>

namespace godot
{

class AthenaDevice : public Node
{
    GDCLASS(AthenaDevice, Node)

protected:
    static void _bind_methods();

public:
    AthenaDevice() = default;
    ~AthenaDevice() override;

    bool initialize();
    void shutdown();
    int32_t ping() const;
    Dictionary get_abi_info() const;
    Dictionary get_status() const;
    String get_connection_state_name() const;
    Dictionary get_latest_imu() const;
    Dictionary get_frame_metadata(int32_t stream) const;
    PackedByteArray copy_frame_bytes(int32_t stream) const;
    Ref<Image> get_rgb_image() const;
    Ref<ImageTexture> get_rgb_texture() const;
    Array get_apriltags(int32_t max_count) const;

    void set_device_mxid(const String& device_mxid);
    String get_device_mxid() const;

    void set_allow_simulated_fallback(bool allow_simulated_fallback);
    bool get_allow_simulated_fallback() const;

    void set_enable_rgb(bool enable_rgb);
    bool get_enable_rgb() const;

    void set_enable_ir(bool enable_ir);
    bool get_enable_ir() const;

    void set_enable_thermal(bool enable_thermal);
    bool get_enable_thermal() const;

    void set_enable_imu(bool enable_imu);
    bool get_enable_imu() const;

    void set_enable_apriltags(bool enable_apriltags);
    bool get_enable_apriltags() const;

    void set_thermal_left_device(const String& value);
    String get_thermal_left_device() const;

    void set_thermal_right_device(const String& value);
    String get_thermal_right_device() const;

    void set_apriltag_detector_stream(int32_t value);
    int32_t get_apriltag_detector_stream() const;

    void set_apriltag_tag_size_m(double value);
    double get_apriltag_tag_size_m() const;

    void set_apriltag_max_reprojection_error_px(double value);
    double get_apriltag_max_reprojection_error_px() const;

    enum Stream
    {
        STREAM_RGB = 0,
        STREAM_IR_LEFT = 1,
        STREAM_IR_RIGHT = 2,
        STREAM_THERMAL_LEFT = 3,
        STREAM_THERMAL_RIGHT = 4
    };

private:
    AthenaConfig make_config() const;

    String device_mxid_;
    bool allow_simulated_fallback_ = false;
    bool enable_rgb_ = true;
    bool enable_ir_ = true;
    bool enable_thermal_ = false;
    bool enable_imu_ = true;
    bool enable_apriltags_ = true;
    String thermal_left_device_;
    String thermal_right_device_;
    int32_t apriltag_detector_stream_ = 0;
    double apriltag_tag_size_m_ = 0.16;
    double apriltag_max_reprojection_error_px_ = 8.0;
    bool initialized_ = false;
};

} // namespace godot

VARIANT_ENUM_CAST(godot::AthenaDevice::Stream)
