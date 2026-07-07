cmake_minimum_required(VERSION 3.20)

foreach(_required_var IN ITEMS
    ATHENA_RUNTIME_DIST_DIR
    ATHENA_RUNTIME_ADDON_DIR
    ATHENA_RUNTIME_BIN_DIR
    ATHENA_GDEXTENSION_SOURCE
    ATHENA_GODOT_LIBRARY
    ATHENA_NATIVE_LIBRARY
    ATHENA_OPENCV_PACKAGE_DIR
    ATHENA_DEPTHAI_PACKAGE_DIR
)
    if(NOT DEFINED ${_required_var} OR "${${_required_var}}" STREQUAL "")
        message(FATAL_ERROR "${_required_var} is required.")
    endif()
endforeach()

foreach(_prefix IN ITEMS "${ATHENA_OPENCV_PACKAGE_DIR}" "${ATHENA_DEPTHAI_PACKAGE_DIR}")
    if(_prefix STREQUAL "/usr" OR _prefix MATCHES "^/usr/(lib|include|local)(/|$)")
        message(FATAL_ERROR "Refusing to package host dependency path: ${_prefix}")
    endif()
endforeach()

file(REMOVE_RECURSE "${ATHENA_RUNTIME_DIST_DIR}")
file(MAKE_DIRECTORY "${ATHENA_RUNTIME_ADDON_DIR}" "${ATHENA_RUNTIME_BIN_DIR}")

file(READ "${ATHENA_GDEXTENSION_SOURCE}" _gdextension_contents)
string(REGEX REPLACE
    "linux\\.debug\\.x86_64[ \t]*=[ \t]*\"[^\"]+\""
    "linux.debug.x86_64 = \"res://addons/athena/bin/linux.x86_64/libathena_godot.so\""
    _gdextension_contents
    "${_gdextension_contents}"
)
string(REGEX REPLACE
    "linux\\.release\\.x86_64[ \t]*=[ \t]*\"[^\"]+\""
    "linux.release.x86_64 = \"res://addons/athena/bin/linux.x86_64/libathena_godot.so\""
    _gdextension_contents
    "${_gdextension_contents}"
)
file(WRITE "${ATHENA_RUNTIME_ADDON_DIR}/athena.gdextension" "${_gdextension_contents}")

file(COPY
    "${ATHENA_GODOT_LIBRARY}"
    "${ATHENA_NATIVE_LIBRARY}"
    DESTINATION "${ATHENA_RUNTIME_BIN_DIR}"
)

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
        DESTINATION "${ATHENA_RUNTIME_BIN_DIR}"
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
    DESTINATION "${ATHENA_RUNTIME_BIN_DIR}"
    FOLLOW_SYMLINK_CHAIN
)

find_program(_patchelf_executable patchelf REQUIRED)
file(GLOB _packaged_runtime_libs "${ATHENA_RUNTIME_BIN_DIR}/*.so*")
foreach(_runtime_lib IN LISTS _packaged_runtime_libs)
    if(NOT IS_SYMLINK "${_runtime_lib}")
        execute_process(
            COMMAND
                "${_patchelf_executable}"
                "--set-rpath"
                "$ORIGIN"
                "${_runtime_lib}"
            RESULT_VARIABLE _patchelf_result
            OUTPUT_VARIABLE _patchelf_output
            ERROR_VARIABLE _patchelf_error
        )

        if(NOT _patchelf_result EQUAL 0)
            message(FATAL_ERROR
                "Failed to set packaged runtime rpath for ${_runtime_lib}:\n"
                "${_patchelf_output}${_patchelf_error}"
            )
        endif()
    endif()
endforeach()

find_program(_ldd_executable ldd REQUIRED)
execute_process(
    COMMAND "${_ldd_executable}" "${ATHENA_RUNTIME_BIN_DIR}/libathena_plugin.so"
    RESULT_VARIABLE _ldd_result
    OUTPUT_VARIABLE _ldd_output
    ERROR_VARIABLE _ldd_error
)

message(STATUS "Packaged runtime ldd output:\n${_ldd_output}${_ldd_error}")

if(NOT _ldd_result EQUAL 0)
    message(FATAL_ERROR "ldd failed for packaged libathena_plugin.so.")
endif()

if(_ldd_output MATCHES "not found" OR _ldd_error MATCHES "not found")
    message(FATAL_ERROR
        "Packaged libathena_plugin.so still has unresolved runtime dependencies."
    )
endif()

string(FIND "${_ldd_output}${_ldd_error}" "${ATHENA_OPENCV_PACKAGE_DIR}" _opencv_package_ref)
string(FIND "${_ldd_output}${_ldd_error}" "${ATHENA_DEPTHAI_PACKAGE_DIR}" _depthai_package_ref)
if(NOT _opencv_package_ref EQUAL -1 OR NOT _depthai_package_ref EQUAL -1)
    message(FATAL_ERROR
        "Packaged libathena_plugin.so still resolves runtime dependencies from "
        "the provisioned build tree instead of ${ATHENA_RUNTIME_BIN_DIR}."
    )
endif()

message(STATUS "Packaged Athena runtime: ${ATHENA_RUNTIME_DIST_DIR}")
