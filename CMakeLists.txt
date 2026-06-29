cmake_minimum_required(VERSION 3.20)

project(athena_plugin_godot
    VERSION 0.1.0
    LANGUAGES CXX
)

set(GODOT_CPP_DIR
    "${CMAKE_CURRENT_SOURCE_DIR}/third_party/godot-cpp"
    CACHE PATH
    "Path to a godot-cpp checkout"
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

if(NOT EXISTS "${GODOT_CPP_DIR}/CMakeLists.txt")
    message(FATAL_ERROR
        "godot-cpp was not found at ${GODOT_CPP_DIR}. "
        "Clone https://github.com/godotengine/godot-cpp there or pass -DGODOT_CPP_DIR=/path/to/godot-cpp."
    )
endif()

if(NOT EXISTS "${ATHENA_NATIVE_PLUGIN_DIR}/include/athena_plugin/athena_plugin.h")
    message(FATAL_ERROR
        "Native Athena plugin headers were not found at ${ATHENA_NATIVE_PLUGIN_DIR}. "
        "Pass -DATHENA_NATIVE_PLUGIN_DIR=/path/to/athena-plugin."
    )
endif()

set(ATHENA_PLUGIN_BUILD_EXAMPLES OFF CACHE BOOL "" FORCE)

add_subdirectory("${GODOT_CPP_DIR}" "${CMAKE_CURRENT_BINARY_DIR}/godot-cpp")
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
