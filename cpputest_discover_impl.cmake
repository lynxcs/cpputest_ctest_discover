# Distributed under the OSI-approved BSD 3-Clause License.  See accompanying
# file Copyright.txt or https://cmake.org/licensing for details.

function(add_command NAME)
    set(_args "")
    # use ARGV* instead of ARGN, because ARGN splits arrays into multiple arguments
    math(EXPR _last_arg ${ARGC}-1)
    foreach(_n RANGE 1 ${_last_arg})
        set(_arg "${ARGV${_n}}")
        if(_arg MATCHES "[^-./:a-zA-Z0-9_]")
            set(_args "${_args} [==[${_arg}]==]") # form a bracket_argument
        else()
            set(_args "${_args} ${_arg}")
        endif()
    endforeach()
    set(script "${script}${NAME}(${_args})\n" PARENT_SCOPE)
endfunction()

function(cpputest_discover_tests_impl)
    cmake_parse_arguments(
        ""
        ""
        "TEST_TARGET;TEST_EXECUTABLE;TEST_WORKING_DIR;TEST_PREFIX;TEST_REPORTER;TEST_SPEC;TEST_SUFFIX;TEST_LIST;CTEST_FILE;TEST_RUN_COUNT"
        "TEST_EXTRA_ARGS;TEST_PROPERTIES"
        ${ARGN}
    )

    set(prefix "${_TEST_PREFIX}")
    set(suffix "${_TEST_SUFFIX}")
    set(spec ${_TEST_SPEC})
    set(extra_args ${_TEST_EXTRA_ARGS})
    set(properties ${_TEST_PROPERTIES})
    set(reporter ${_TEST_REPORTER})
    set(script)
    set(suite)
    set(tests)

    # Run test executable to get list of available tests
    if(NOT EXISTS "${_TEST_EXECUTABLE}")
        message(FATAL_ERROR
            "Specified test executable '${_TEST_EXECUTABLE}' does not exist"
        )
    endif()

    execute_process(
        COMMAND "${_TEST_EXECUTABLE}" ${spec} -ln
        OUTPUT_VARIABLE output
        RESULT_VARIABLE result
        WORKING_DIRECTORY "${_TEST_WORKING_DIR}"
    )
    if(NOT ${result} EQUAL 0)
        message(FATAL_ERROR
            "Error running test executable '${_TEST_EXECUTABLE}':\n"
            "    Result: ${result}\n"
            "    Output: ${output}\n"
        )
    endif()

    # Make sure to escape ; (semicolons) in test names first, because
    # that'd break the foreach loop for "Parse output" later and create
    # wrongly splitted and thus failing test cases (false positives)
    string(REPLACE ";" "\;" output "${output}")
    string(REPLACE "\n" ";" output "${output}")
    string(REPLACE " " ";" output "${output}")

    # Prepare reporter
    if(reporter)
        set(reporter_arg "-o${reporter}")
    endif()

    # Parse output
    foreach(line ${output})
        set(test "${line}")
        # Note that the \ escaping must happen FIRST! Do not change the order.
        set(test_name "${test}")
        foreach(char \\ , [ ])
            string(REPLACE ${char} "\\${char}" test_name "${test_name}")
        endforeach(char)

        # ...and add to script
        foreach(loopCount RANGE 1 ${_TEST_RUN_COUNT} 1)
            add_command(add_test
                "${prefix}${test}${suffix} (Nr.: ${loopCount})"
                "${_TEST_EXECUTABLE}"
                "-st"
                "${test_name}"
                "-k"
                "${_TEST_TARGET}${test}${loopCount}"
                ${extra_args}
                "${reporter_arg}"
            )
            add_command(set_tests_properties
                "${prefix}${test}${suffix}"
                PROPERTIES
                WORKING_DIRECTORY "${_TEST_WORKING_DIR}"
                ${properties}
            )

            if(environment_modifications)
                add_command(set_tests_properties
                    "${prefix}${test}${suffix}"
                    PROPERTIES
                    ENVIRONMENT_MODIFICATION "${environment_modifications}"
                )
            endif()

            list(APPEND tests "${prefix}${test}${suffix}")
        endforeach()
    endforeach()

    # Create a list of all discovered tests, which users may use to e.g. set
    # properties on the tests
    add_command(set ${_TEST_LIST} ${tests})

    # Write CTest script
    file(WRITE "${_CTEST_FILE}" "${script}")
endfunction()

if(CMAKE_SCRIPT_MODE_FILE)
    cpputest_discover_tests_impl(
        TEST_TARGET ${TEST_TARGET}
        TEST_EXECUTABLE ${TEST_EXECUTABLE}
        TEST_WORKING_DIR ${TEST_WORKING_DIR}
        TEST_SPEC ${TEST_SPEC}
        TEST_EXTRA_ARGS ${TEST_EXTRA_ARGS}
        TEST_PROPERTIES ${TEST_PROPERTIES}
        TEST_PREFIX ${TEST_PREFIX}
        TEST_SUFFIX ${TEST_SUFFIX}
        TEST_LIST ${TEST_LIST}
        TEST_REPORTER ${TEST_REPORTER}
        TEST_RUN_COUNT ${TEST_RUN_COUNT}
        CTEST_FILE ${CTEST_FILE}
    )
endif()