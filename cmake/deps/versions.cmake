# Pinned production dependency versions.
#
# depthai-core: real Luxonis/OAK device runtime used by the native Athena
# backend. Use the official source release because it includes bundled shared
# sources that plain git archives do not include.
set(ATHENA_DEPS_DEPTHAI_VERSION "2.29.0")
set(ATHENA_DEPS_DEPTHAI_URL
    "https://github.com/luxonis/depthai-core/releases/download/v2.29.0/depthai-core-v2.29.0.tar.gz"
)

# OpenCV: host-side AprilTag detection and pose estimation in
# depthai_backend.cpp. Required modules are core, imgproc, calib3d, and
# objdetect. OpenCV contrib is intentionally not provisioned.
set(ATHENA_DEPS_OPENCV_VERSION "4.10.0")
set(ATHENA_DEPS_OPENCV_GIT_REPOSITORY "https://github.com/opencv/opencv.git")
set(ATHENA_DEPS_OPENCV_GIT_TAG "4.10.0")

# libusb: USB transport required by DepthAI/XLink. DepthAI 2.29 provisions the
# Luxonis libusb fork through its pinned Hunter configuration; the commit is
# documented here so the real USB dependency is visible at this layer too.
set(ATHENA_DEPS_LIBUSB_LUXONIS_COMMIT "b7e4548958325b18feb73977163ad44398099534")
set(ATHENA_DEPS_LIBUSB_LUXONIS_URL
    "https://github.com/luxonis/libusb/archive/b7e4548958325b18feb73977163ad44398099534.tar.gz"
)

# Hunter is used only inside the isolated DepthAI provisioning build. The main
# plugin configure never invokes Hunter or downloads dependencies.
set(ATHENA_DEPS_DEPTHAI_HUNTER_COMMIT "9d9242b60d5236269f894efd3ddd60a9ca83dd7f")
set(ATHENA_DEPS_DEPTHAI_HUNTER_SHA1 "16cc954aa723bccd16ea45fc91a858d0c5246376")

# Protobuf is not built for the selected DepthAI 2.29 path and is not required
# by the native Athena plugin or the selected OpenCV module set. If a future
# DepthAI profile requires protobuf, add the exact version here and wire it
# through cmake/provision explicitly before enabling that profile.
set(ATHENA_DEPS_PROTOBUF_REQUIRED OFF)
set(ATHENA_DEPS_PROTOBUF_VERSION "not-used")
