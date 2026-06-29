set(ATHENA_AARCH64_TARGET "aarch64-unknown-linux-gnu" CACHE STRING "" FORCE)
set(ATHENA_AARCH64_SYSROOT
    "${CMAKE_CURRENT_LIST_DIR}/../../build/sysroots/archlinuxarm-aarch64"
    CACHE PATH "" FORCE
)
set(CMAKE_POLICY_VERSION_MINIMUM "3.5" CACHE STRING "" FORCE)

include("${CMAKE_CURRENT_LIST_DIR}/linux-aarch64-clang.cmake")
