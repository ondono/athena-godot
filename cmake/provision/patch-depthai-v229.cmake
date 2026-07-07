if(NOT DEFINED DEPTHAI_SOURCE_DIR)
    message(FATAL_ERROR "DEPTHAI_SOURCE_DIR is required.")
endif()

set(_depthai_cmakelists "${DEPTHAI_SOURCE_DIR}/CMakeLists.txt")
set(_depthai_hunter_gate "${DEPTHAI_SOURCE_DIR}/cmake/HunterGate.cmake")

if(NOT EXISTS "${_depthai_cmakelists}")
    message(FATAL_ERROR "DepthAI source tree is missing CMakeLists.txt: ${DEPTHAI_SOURCE_DIR}")
endif()

file(READ "${_depthai_cmakelists}" _depthai_cmakelists_text)
string(REPLACE
    "cmake_minimum_required(VERSION 3.4)"
    "cmake_minimum_required(VERSION 3.5)"
    _depthai_cmakelists_text
    "${_depthai_cmakelists_text}"
)
file(WRITE "${_depthai_cmakelists}" "${_depthai_cmakelists_text}")

if(EXISTS "${_depthai_hunter_gate}")
    file(READ "${_depthai_hunter_gate}" _depthai_hunter_gate_text)
    string(REPLACE
        "cmake_minimum_required(VERSION 3.2)"
        "cmake_minimum_required(VERSION 3.5)"
        _depthai_hunter_gate_text
        "${_depthai_hunter_gate_text}"
    )
    file(WRITE "${_depthai_hunter_gate}" "${_depthai_hunter_gate_text}")
endif()

if(NOT EXISTS "${DEPTHAI_SOURCE_DIR}/shared/depthai-shared/src/datatype/DatatypeEnum.cpp")
    message(FATAL_ERROR
        "DepthAI source package is missing bundled depthai-shared sources. "
        "Use the official depthai-core ${ATHENA_DEPS_DEPTHAI_VERSION} release archive."
    )
endif()
