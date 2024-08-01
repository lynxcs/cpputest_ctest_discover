# Distributed under the OSI-approved BSD 3-Clause License.  See accompanying
# file Copyright.txt or https://cmake.org/licensing for details.

#[=======================================================================[.rst:

This module defines a function to help use the cpputest test framework.

Strongly based on similiar solutions available for Catch & doctest

.. command:: cpputest_discover_tests

  Automatically add tests with CTest by querying the compiled test executable
  for available tests::

    cpputest_discover_tests(target
                         [TEST_SPEC arg1...]
                         [EXTRA_ARGS arg1...]
                         [WORKING_DIRECTORY dir]
                         [TEST_PREFIX prefix]
                         [TEST_SUFFIX suffix]
                         [PROPERTIES name1 value1...]
                         [TEST_LIST var]
                         [REPORTER reporter]
    )

  The options are:

  ``target``
    Specifies the cpputest executable, which must be a known CMake executable
    target.  CMake will substitute the location of the built executable when
    running the test.

  ``TEST_SPEC arg1...``
    Specifies test cases, wildcarded test cases, tags and tag expressions to
    pass to the cpputest executable with the ``--list-test-names-only`` argument.

  ``EXTRA_ARGS arg1...``
    Any extra arguments to pass on the command line to each test case.

  ``WORKING_DIRECTORY dir``
    Specifies the directory in which to run the discovered test cases.  If this
    option is not provided, the current binary directory is used.

  ``TEST_PREFIX prefix``
    Specifies a ``prefix`` to be prepended to the name of each discovered test
    case.  This can be useful when the same test executable is being used in
    multiple calls to ``cpputest_discover_tests()`` but with different
    ``TEST_SPEC`` or ``EXTRA_ARGS``.

  ``TEST_SUFFIX suffix``
    Similar to ``TEST_PREFIX`` except the ``suffix`` is appended to the name of
    every discovered test case.  Both ``TEST_PREFIX`` and ``TEST_SUFFIX`` may
    be specified.

  ``PROPERTIES name1 value1...``
    Specifies additional properties to be set on all tests discovered by this
    invocation of ``cpputest_discover_tests``.

  ``TEST_LIST var``
    Make the list of tests available in the variable ``var``, rather than the
    default ``<target>_TESTS``.  This can be useful when the same test
    executable is being used in multiple calls to ``cpputest_discover_tests()``.
    Note that this variable is only available in CTest.

  ``REPORTER reporter``
    Use the specified reporter when running the test case. The reporter will
    be passed to the cpputest executable as ``-oreporter``.

#]=======================================================================]

#------------------------------------------------------------------------------
function(cpputest_discover_tests TARGET)
    cmake_parse_arguments("" ""
        "TEST_PREFIX;TEST_SUFFIX;WORKING_DIRECTORY;TEST_LIST;REPORTER;RUN_COUNT"
        "TEST_SPEC;EXTRA_ARGS;PROPERTIES"
        ${ARGN}
    )

    if(NOT _WORKING_DIRECTORY)
        set(_WORKING_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}")
    endif()
    if(NOT _TEST_LIST)
        set(_TEST_LIST ${TARGET}_TESTS)
    endif()

    ## Generate a unique name based on the extra arguments
    string(SHA1 args_hash "${_TEST_SPEC} ${_EXTRA_ARGS} ${_REPORTER}")
    string(SUBSTRING ${args_hash} 0 7 args_hash)

    # Define rule to generate test list for aforementioned test executable
    set(ctest_file_base "${CMAKE_CURRENT_BINARY_DIR}/${TARGET}-${args_hash}")
    set(ctest_include_file "${ctest_file_base}_include.cmake")
    set(ctest_tests_file "${ctest_file_base}_tests.cmake")

    add_custom_command(
        TARGET ${TARGET} POST_BUILD
        BYPRODUCTS "${ctest_tests_file}"
        COMMAND "${CMAKE_COMMAND}"
                -D "TEST_TARGET=${TARGET}"
                -D "TEST_EXECUTABLE=$<TARGET_FILE:${TARGET}>"
                -D "TEST_WORKING_DIR=${_WORKING_DIRECTORY}"
                -D "TEST_SPEC=${_TEST_SPEC}"
                -D "TEST_EXTRA_ARGS=${_EXTRA_ARGS}"
                -D "TEST_PROPERTIES=${_PROPERTIES}"
                -D "TEST_PREFIX=${_TEST_PREFIX}"
                -D "TEST_SUFFIX=${_TEST_SUFFIX}"
                -D "TEST_LIST=${_TEST_LIST}"
                -D "TEST_REPORTER=${_REPORTER}"
                -D "TEST_RUN_COUNT=${_RUN_COUNT}"
                -D "CTEST_FILE=${ctest_tests_file}"
                -P "${_CPPUTEST_DISCOVER_TESTS_SCRIPT}"
        VERBATIM
    )

    file(WRITE "${ctest_include_file}"
        "if(EXISTS \"${ctest_tests_file}\")\n"
        "    include(\"${ctest_tests_file}\")\n"
        "else()\n"
        "    add_test(${TARGET}_NOT_BUILT-${args_hash} ${TARGET}_NOT_BUILT-${args_hash})\n"
        "endif()\n"
    )

    # Add discovered tests to directory TEST_INCLUDE_FILES
    set_property(DIRECTORY
        APPEND PROPERTY TEST_INCLUDE_FILES "${ctest_include_file}"
    )
endfunction()

set(_CPPUTEST_DISCOVER_TESTS_SCRIPT
    ${CMAKE_CURRENT_LIST_DIR}/cpputest_discover_impl.cmake
    CACHE INTERNAL "Discover script path"
)
