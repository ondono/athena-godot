if(NOT DEFINED ATHENA_DEPS_PREFIX OR NOT DEFINED ATHENA_PROVISION_TARGET)
    message(FATAL_ERROR "ATHENA_DEPS_PREFIX and ATHENA_PROVISION_TARGET are required.")
endif()

set(_depthai_config "${ATHENA_DEPS_PREFIX}/depthai/lib/cmake/depthai/depthaiConfig.cmake")
set(_opencv_config "${ATHENA_DEPS_PREFIX}/opencv/lib/cmake/opencv4/OpenCVConfig.cmake")

if(NOT EXISTS "${_depthai_config}")
    message(FATAL_ERROR "Provisioned DepthAI config missing: ${_depthai_config}")
endif()

if(NOT EXISTS "${_opencv_config}")
    message(FATAL_ERROR "Provisioned OpenCV config missing: ${_opencv_config}")
endif()

file(GLOB_RECURSE _depthai_libusb
    "${ATHENA_DEPS_PREFIX}/depthai/lib/cmake/depthai/dependencies/lib/libusb-1.0.so"
    "${ATHENA_DEPS_PREFIX}/depthai/lib/cmake/depthai/dependencies/lib/libusb-1.0.a"
    "${ATHENA_DEPS_PREFIX}/depthai/lib/cmake/depthai/dependencies/*/libusb-1.0.so"
    "${ATHENA_DEPS_PREFIX}/depthai/lib/cmake/depthai/dependencies/*/libusb-1.0.a"
    "${ATHENA_DEPS_PREFIX}/depthai/lib/cmake/depthai/dependencies/*/*/libusb-1.0.so"
    "${ATHENA_DEPS_PREFIX}/depthai/lib/cmake/depthai/dependencies/*/*/libusb-1.0.a"
)

if(NOT _depthai_libusb)
    message(FATAL_ERROR
        "Provisioned DepthAI package does not contain an explicit libusb runtime/library "
        "under ${ATHENA_DEPS_PREFIX}/depthai/lib/cmake/depthai/dependencies."
    )
endif()

message(STATUS "Provisioned ${ATHENA_PROVISION_TARGET} dependencies:")
message(STATUS "  DepthAI: ${_depthai_config}")
message(STATUS "  OpenCV:  ${_opencv_config}")
message(STATUS "  libusb:  ${_depthai_libusb}")
