cmake_minimum_required(VERSION 3.20)

foreach(_required_var IN ITEMS
    ATHENA_RUNTIME_OUTPUT_DIR
    ATHENA_OPENCV_PACKAGE_DIR
    ATHENA_DEPTHAI_PACKAGE_DIR
)
    if(NOT DEFINED ${_required_var} OR "${${_required_var}}" STREQUAL "")
        message(FATAL_ERROR "${_required_var} is required.")
    endif()
endforeach()

file(MAKE_DIRECTORY "${ATHENA_RUNTIME_OUTPUT_DIR}")

file(GLOB _opencv_runtime_libs
    "${ATHENA_OPENCV_PACKAGE_DIR}/lib/libopencv_*.so*"
)
if(NOT _opencv_runtime_libs)
    message(FATAL_ERROR
        "No OpenCV runtime libraries found under ${ATHENA_OPENCV_PACKAGE_DIR}/lib."
    )
endif()

foreach(_opencv_lib IN LISTS _opencv_runtime_libs)
    file(COPY "${_opencv_lib}"
        DESTINATION "${ATHENA_RUNTIME_OUTPUT_DIR}"
        FOLLOW_SYMLINK_CHAIN
    )
endforeach()

set(_libusb_candidates
    "${ATHENA_DEPTHAI_PACKAGE_DIR}/lib/cmake/depthai/dependencies/lib/libusb-1.0.so"
    "${ATHENA_DEPTHAI_PACKAGE_DIR}/lib/cmake/depthai/dependencies/lib/cmake/XLink/dependencies/lib/libusb-1.0.so"
)
set(_libusb_runtime_lib "")
foreach(_candidate IN LISTS _libusb_candidates)
    if(EXISTS "${_candidate}")
        set(_libusb_runtime_lib "${_candidate}")
        break()
    endif()
endforeach()

if(NOT _libusb_runtime_lib)
    message(FATAL_ERROR
        "Provisioned libusb runtime not found under ${ATHENA_DEPTHAI_PACKAGE_DIR}."
    )
endif()

file(COPY "${_libusb_runtime_lib}"
    DESTINATION "${ATHENA_RUNTIME_OUTPUT_DIR}"
    FOLLOW_SYMLINK_CHAIN
)

message(STATUS "Staged Athena runtime dependencies: ${ATHENA_RUNTIME_OUTPUT_DIR}")
