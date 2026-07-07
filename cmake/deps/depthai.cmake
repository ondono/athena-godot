option(ATHENA_ENABLE_DEPTHAI "Build against the real Luxonis DepthAI backend" ON)
include(cmake/deps/prefix_guard.cmake)

set(ATHENA_DEPTHAI_API_VERSION
    "2"
    CACHE STRING
    "DepthAI C++ API major version to compile against: 2 or 3"
)
set_property(CACHE ATHENA_DEPTHAI_API_VERSION PROPERTY STRINGS 2 3)

set(ATHENA_DEPTHAI_PACKAGE_DIR
    ""
    CACHE PATH
    "Explicit DepthAI CMake package prefix containing lib/cmake/depthai/depthaiConfig.cmake"
)
set(ATHENA_DEPTHAI_SOURCE_DIR "" CACHE PATH "Unsupported for production plugin configure")
set(ATHENA_DEPTHAI_PREBUILT_ROOT "" CACHE PATH "Unsupported for production plugin configure")

if(NOT ATHENA_ENABLE_DEPTHAI)
    message(FATAL_ERROR
        "ATHENA_ENABLE_DEPTHAI=OFF would produce a simulated/no-camera build. "
        "That profile is intentionally out of scope for production presets."
    )
endif()

if(NOT ATHENA_DEPTHAI_API_VERSION STREQUAL "2" AND NOT ATHENA_DEPTHAI_API_VERSION STREQUAL "3")
    message(FATAL_ERROR "ATHENA_DEPTHAI_API_VERSION must be 2 or 3.")
endif()

set(ATHENA_DEPTHAI_EXPLICIT_ROOT_COUNT 0)
foreach(ATHENA_DEPTHAI_ROOT IN ITEMS
    ATHENA_DEPTHAI_PACKAGE_DIR
    ATHENA_DEPTHAI_SOURCE_DIR
    ATHENA_DEPTHAI_PREBUILT_ROOT
)
    if(${ATHENA_DEPTHAI_ROOT})
        math(EXPR ATHENA_DEPTHAI_EXPLICIT_ROOT_COUNT "${ATHENA_DEPTHAI_EXPLICIT_ROOT_COUNT} + 1")
    endif()
endforeach()

if(ATHENA_DEPTHAI_EXPLICIT_ROOT_COUNT EQUAL 0)
    message(FATAL_ERROR
        "A real DepthAI dependency path is required. Set ATHENA_DEPTHAI_PACKAGE_DIR, "
        "ATHENA_DEPTHAI_SOURCE_DIR, or ATHENA_DEPTHAI_PREBUILT_ROOT explicitly."
    )
endif()

if(ATHENA_DEPTHAI_SOURCE_DIR OR ATHENA_DEPTHAI_PREBUILT_ROOT)
    message(FATAL_ERROR
        "Normal plugin configure consumes provisioned DepthAI package prefixes only. "
        "Run scripts/provision-deps.sh <target> and set ATHENA_DEPTHAI_PACKAGE_DIR "
        "under build/deps/<target>/depthai."
    )
endif()

if(ATHENA_DEPTHAI_PACKAGE_DIR)
    athena_require_provisioned_prefix(ATHENA_DEPTHAI_PACKAGE_DIR)
    get_filename_component(ATHENA_DEPTHAI_PACKAGE_DIR_ABS
        "${ATHENA_DEPTHAI_PACKAGE_DIR}"
        ABSOLUTE
    )
    if(ATHENA_DEPTHAI_PACKAGE_DIR_ABS STREQUAL "/usr"
        OR ATHENA_DEPTHAI_PACKAGE_DIR_ABS MATCHES "^/usr/(lib|include|local)(/|$)"
    )
        message(FATAL_ERROR
            "ATHENA_DEPTHAI_PACKAGE_DIR points at a host system path (${ATHENA_DEPTHAI_PACKAGE_DIR}). "
            "Use an explicit packaged DepthAI prefix built for the target ABI."
        )
    endif()
    set(ATHENA_DEPTHAI_CONFIG
        "${ATHENA_DEPTHAI_PACKAGE_DIR}/lib/cmake/depthai/depthaiConfig.cmake"
    )
    if(NOT EXISTS "${ATHENA_DEPTHAI_CONFIG}")
        message(FATAL_ERROR
            "DepthAI package config missing: ${ATHENA_DEPTHAI_CONFIG}"
        )
    endif()
    set(depthai_DIR
        "${ATHENA_DEPTHAI_PACKAGE_DIR}/lib/cmake/depthai"
        CACHE PATH
        "DepthAI package directory"
        FORCE
    )
    list(PREPEND CMAKE_PREFIX_PATH "${ATHENA_DEPTHAI_PACKAGE_DIR}")
endif()
