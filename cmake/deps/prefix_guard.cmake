function(athena_require_provisioned_prefix variable_name)
    if(NOT DEFINED ${variable_name} OR "${${variable_name}}" STREQUAL "")
        message(FATAL_ERROR "${variable_name} must be set to a provisioned dependency prefix.")
    endif()

    get_filename_component(_athena_prefix "${${variable_name}}" ABSOLUTE)
    get_filename_component(_athena_deps_root
        "${CMAKE_CURRENT_SOURCE_DIR}/build/deps"
        ABSOLUTE
    )

    if(NOT _athena_prefix MATCHES "^${_athena_deps_root}/(linux-x86_64|debian12-aarch64)(/|$)")
        message(FATAL_ERROR
            "${variable_name} must point under ${_athena_deps_root}/<target>, "
            "got: ${${variable_name}}"
        )
    endif()

    if(_athena_prefix STREQUAL "/usr"
        OR _athena_prefix MATCHES "^/usr/(lib|include|local)(/|$)"
    )
        message(FATAL_ERROR
            "${variable_name} points at a host system path (${${variable_name}}). "
            "Use scripts/provision-deps.sh to create build/deps/<target> instead."
        )
    endif()
endfunction()
