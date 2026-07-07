set(GODOT_CPP_DIR
    "${CMAKE_CURRENT_SOURCE_DIR}/third_party/godot-cpp"
    CACHE PATH
    "Path to a godot-cpp checkout"
)

if(NOT EXISTS "${GODOT_CPP_DIR}/CMakeLists.txt")
    message(FATAL_ERROR
        "godot-cpp was not found at ${GODOT_CPP_DIR}. "
        "Run tools/bootstrap-godot-cpp.sh or pass -DGODOT_CPP_DIR=/path/to/godot-cpp."
    )
endif()

add_subdirectory("${GODOT_CPP_DIR}" "${CMAKE_CURRENT_BINARY_DIR}/godot-cpp")
