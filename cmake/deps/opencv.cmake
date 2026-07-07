set(ATHENA_OPENCV_PACKAGE_DIR
    ""
    CACHE PATH
    "Explicit OpenCV CMake package prefix containing OpenCVConfig.cmake"
)
include(cmake/deps/prefix_guard.cmake)

if(NOT ATHENA_OPENCV_PACKAGE_DIR)
    message(FATAL_ERROR
        "ATHENA_OPENCV_PACKAGE_DIR is required. Do not rely on host OpenCV; "
        "pass an explicit Debian 12-compatible OpenCV package root."
    )
endif()

athena_require_provisioned_prefix(ATHENA_OPENCV_PACKAGE_DIR)

get_filename_component(ATHENA_OPENCV_PACKAGE_DIR_ABS
    "${ATHENA_OPENCV_PACKAGE_DIR}"
    ABSOLUTE
)
if(ATHENA_OPENCV_PACKAGE_DIR_ABS STREQUAL "/usr"
    OR ATHENA_OPENCV_PACKAGE_DIR_ABS MATCHES "^/usr/(lib|include|local)(/|$)"
)
    message(FATAL_ERROR
        "ATHENA_OPENCV_PACKAGE_DIR points at host system OpenCV (${ATHENA_OPENCV_PACKAGE_DIR}). "
        "Use a Debian 12-compatible dependency prefix or sysroot path instead."
    )
endif()

find_file(ATHENA_OPENCV_CONFIG
    NAMES OpenCVConfig.cmake opencv-config.cmake
    PATHS "${ATHENA_OPENCV_PACKAGE_DIR}"
    PATH_SUFFIXES
        .
        lib/cmake/opencv4
        lib/cmake/opencv5
        lib/aarch64-linux-gnu/cmake/opencv4
        lib/x86_64-linux-gnu/cmake/opencv4
    NO_DEFAULT_PATH
    NO_CMAKE_FIND_ROOT_PATH
)

if(NOT ATHENA_OPENCV_CONFIG)
    message(FATAL_ERROR
        "OpenCVConfig.cmake was not found under ATHENA_OPENCV_PACKAGE_DIR=${ATHENA_OPENCV_PACKAGE_DIR}."
    )
endif()

get_filename_component(ATHENA_OPENCV_CONFIG_DIR "${ATHENA_OPENCV_CONFIG}" DIRECTORY)
set(OpenCV_DIR
    "${ATHENA_OPENCV_CONFIG_DIR}"
    CACHE PATH
    "OpenCV package directory"
    FORCE
)
list(PREPEND CMAKE_PREFIX_PATH "${ATHENA_OPENCV_PACKAGE_DIR}" "${ATHENA_OPENCV_CONFIG_DIR}")
