find_package(SmokeTests)

set(TEST_SOURCES
    "${SMOKETESTS_SOURCE_DIR}/src/pipelinechecks.S" # Pipeline Checks
)

foreach(TEST_SOURCE "${TEST_SOURCES}")
    get_filename_component(TEST_NAME "${TEST_SOURCE}" NAME_WLE)
    set(TEST_BINARY "${SMOKETESTS_BINARY_DIR}/${TEST_NAME}.elf")
    set(TEST_INVOCATION 
        "${CMAKE_BINARY_DIR}/pg10xsim" 
        --sim-host src/ISATestHost/ISATestHost 
        --vcd "${CMAKE_CURRENT_BINARY_DIR}/${TEST_NAME}.vcd" 
        --isa "${BASE_ISA}" 
        --check 
        --max-cycles 30000 
        --log "${CMAKE_CURRENT_BINARY_DIR}/${TEST_NAME}" 
        "${TEST_BINARY}"
    )

    list(JOIN TEST_INVOCATION " " TEST_INVOCATION_STRING)
    file(WRITE "${CMAKE_CURRENT_BINARY_DIR}/${TEST_NAME}.sh" "${TEST_INVOCATION_STRING}")

    add_test(
        NAME "SMOKE_TEST_${TEST_NAME}"
        COMMAND ${TEST_INVOCATION}
        WORKING_DIRECTORY "${CMAKE_BINARY_DIR}"
    )
endforeach()
