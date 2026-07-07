cmake_minimum_required(VERSION 3.20)

project(athena_plugin_godot
    VERSION 0.1.0
    LANGUAGES CXX
)

set(ATHENA_NATIVE_PLUGIN_DIR
    "${CMAKE_CURRENT_SOURCE_DIR}/../../software/athena-plugin"
    CACHE PATH
    "Path to the native Athena plugin source repo"
)
set(ATHENA_GODOT_OUTPUT_SUBDIR
    ""
    CACHE STRING
    "Optional subdirectory under project/bin for platform-specific output"
)
set(ATHENA_TARGET_PROFILE
    "linux-x86_64-dev"
    CACHE STRING
    "Named build profile for diagnostics and packaging"
)
set(ATHENA_TARGET_GLIBC_VERSION
    "2.36"
    CACHE STRING
    "Maximum glibc runtime ABI expected for release artifacts"
)

if(NOT EXISTS "${ATHENA_NATIVE_PLUGIN_DIR}/include/athena_plugin/athena_plugin.h")
    message(FATAL_ERROR
        "Native Athena plugin headers were not found at ${ATHENA_NATIVE_PLUGIN_DIR}. "
        "Pass -DATHENA_NATIVE_PLUGIN_DIR=/path/to/athena-plugin."
    )
endif()

set(CMAKE_FIND_USE_PACKAGE_REGISTRY FALSE)
set(CMAKE_FIND_USE_SYSTEM_PACKAGE_REGISTRY FALSE)
set(CMAKE_FIND_USE_CMAKE_SYSTEM_PATH FALSE)

include(cmake/deps/depthai.cmake)
include(cmake/deps/opencv.cmake)
include(cmake/deps/godot-cpp.cmake)

set(ATHENA_PLUGIN_BUILD_EXAMPLES OFF CACHE BOOL "" FORCE)

add_subdirectory("${ATHENA_NATIVE_PLUGIN_DIR}" "${CMAKE_CURRENT_BINARY_DIR}/athena-native")

set_target_properties(athena_plugin PROPERTIES
    BUILD_WITH_INSTALL_RPATH TRUE
    BUILD_RPATH "$ORIGIN"
    BUILD_RPATH_USE_ORIGIN TRUE
    INSTALL_RPATH "$ORIGIN"
)

add_library(athena_godot SHARED
    src/athena_device.cpp
    src/register_types.cpp
)

target_compile_features(athena_godot
    PUBLIC
        cxx_std_17
)

target_include_directories(athena_godot
    PRIVATE
        "${CMAKE_CURRENT_SOURCE_DIR}/include"
        "${ATHENA_NATIVE_PLUGIN_DIR}/include"
)

target_link_libraries(athena_godot
    PRIVATE
        godot-cpp
        athena_plugin
)

set_target_properties(athena_godot PROPERTIES
    LIBRARY_OUTPUT_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}/project/bin/${ATHENA_GODOT_OUTPUT_SUBDIR}"
    RUNTIME_OUTPUT_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}/project/bin/${ATHENA_GODOT_OUTPUT_SUBDIR}"
    ARCHIVE_OUTPUT_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}/lib"
    BUILD_WITH_INSTALL_RPATH TRUE
    BUILD_RPATH "$ORIGIN"
    BUILD_RPATH_USE_ORIGIN TRUE
    INSTALL_RPATH "$ORIGIN"
)

add_custom_command(TARGET athena_godot POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E copy_if_different
        $<TARGET_FILE:athena_plugin>
        "${CMAKE_CURRENT_SOURCE_DIR}/project/bin/${ATHENA_GODOT_OUTPUT_SUBDIR}/$<TARGET_FILE_NAME:athena_plugin>"
)

add_custom_target(check-abi
    COMMAND
        "${CMAKE_CURRENT_SOURCE_DIR}/scripts/check-abi.sh"
        "--max-glibc"
        "${ATHENA_TARGET_GLIBC_VERSION}"
        "$<TARGET_FILE:athena_godot>"
        "$<TARGET_FILE:athena_plugin>"
    DEPENDS athena_godot athena_plugin
    COMMENT "Checking exported ABI and glibc symbol versions for ${ATHENA_TARGET_PROFILE}"
    VERBATIM
)

if(ATHENA_TARGET_PROFILE STREQUAL "linux-x86_64-release")
    set(ATHENA_RUNTIME_DIST_DIR
        "${CMAKE_CURRENT_SOURCE_DIR}/dist/x86_64/athena-runtime"
    )
    set(ATHENA_RUNTIME_ADDON_DIR "${ATHENA_RUNTIME_DIST_DIR}/addons/athena")
    set(ATHENA_RUNTIME_BIN_DIR "${ATHENA_RUNTIME_ADDON_DIR}/bin/linux.x86_64")

    add_custom_target(package-runtime
        COMMAND
            "${CMAKE_COMMAND}"
            -DATHENA_RUNTIME_DIST_DIR=${ATHENA_RUNTIME_DIST_DIR}
            -DATHENA_RUNTIME_ADDON_DIR=${ATHENA_RUNTIME_ADDON_DIR}
            -DATHENA_RUNTIME_BIN_DIR=${ATHENA_RUNTIME_BIN_DIR}
            -DATHENA_GDEXTENSION_SOURCE=${CMAKE_CURRENT_SOURCE_DIR}/project/bin/athena_godot.gdextension
            -DATHENA_GODOT_LIBRARY=$<TARGET_FILE:athena_godot>
            -DATHENA_NATIVE_LIBRARY=$<TARGET_FILE:athena_plugin>
            -DATHENA_OPENCV_PACKAGE_DIR=${ATHENA_OPENCV_PACKAGE_DIR}
            -DATHENA_DEPTHAI_PACKAGE_DIR=${ATHENA_DEPTHAI_PACKAGE_DIR}
            -P "${CMAKE_CURRENT_SOURCE_DIR}/cmake/package-runtime.cmake"
        DEPENDS check-abi
        COMMENT "Packaging linux-x86_64 Athena runtime"
        VERBATIM
    )
endif()
