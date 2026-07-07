set(CMAKE_SYSTEM_NAME Linux)
set(CMAKE_SYSTEM_PROCESSOR aarch64)

set(ATHENA_TARGET_PROFILE "debian12-aarch64-release" CACHE STRING "Athena target profile")
set(ATHENA_TARGET_GLIBC_VERSION "2.36" CACHE STRING "Maximum supported runtime glibc")
set(ATHENA_AARCH64_TARGET "aarch64-linux-gnu" CACHE STRING "Debian 12 ARM64 target triple")
set(ATHENA_AARCH64_SYSROOT
    "${CMAKE_CURRENT_LIST_DIR}/../../build/sysroots/debian12-arm64"
    CACHE PATH
    "Debian 12 ARM64 sysroot"
)

set(CMAKE_C_COMPILER /usr/bin/aarch64-linux-gnu-gcc CACHE FILEPATH "C compiler" FORCE)
set(CMAKE_CXX_COMPILER /usr/bin/aarch64-linux-gnu-g++ CACHE FILEPATH "C++ compiler" FORCE)

if(NOT EXISTS "${ATHENA_AARCH64_SYSROOT}/usr/include")
    message(FATAL_ERROR
        "Debian 12 ARM64 sysroot is missing: ${ATHENA_AARCH64_SYSROOT}. "
        "Run tools/bootstrap-debian12-sysroot.sh or pass -DATHENA_AARCH64_SYSROOT=/path/to/sysroot."
    )
endif()

foreach(_athena_compiler IN ITEMS "${CMAKE_C_COMPILER}" "${CMAKE_CXX_COMPILER}")
    if(NOT EXISTS "${_athena_compiler}")
        message(FATAL_ERROR
            "Debian 12 ARM64 compiler is missing: ${_athena_compiler}. "
            "Install gcc-aarch64-linux-gnu and g++-aarch64-linux-gnu."
        )
    endif()
endforeach()

set(CMAKE_SYSROOT "${ATHENA_AARCH64_SYSROOT}")
set(CMAKE_FIND_ROOT_PATH "${ATHENA_AARCH64_SYSROOT}")
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE ONLY)

set(CMAKE_AR /usr/bin/aarch64-linux-gnu-ar CACHE FILEPATH "Archiver" FORCE)
set(CMAKE_RANLIB /usr/bin/aarch64-linux-gnu-ranlib CACHE FILEPATH "Ranlib" FORCE)
set(CMAKE_STRIP /usr/bin/aarch64-linux-gnu-strip CACHE FILEPATH "Strip" FORCE)
