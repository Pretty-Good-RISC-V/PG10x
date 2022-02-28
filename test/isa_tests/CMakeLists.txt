find_package(RISCV_ISA_Tests)

if ("${BASE_ISA}" STREQUAL "RV32")
    set(ISA_TEST_BINARIES
        "${RISCV_ISA_TEST_BUILD_DIR}/src/riscv_isa_tests-build/isa/rv32mi-p-csr"     # CSR handling
        # Not run since misaligned load/store not supported"${RISCV_ISA_TEST_BUILD_DIR}/src/riscv_isa_tests-build/isa/rv32mi-p-ma_addr" # Misaligned LD/ST handling
        "${RISCV_ISA_TEST_BUILD_DIR}/src/riscv_isa_tests-build/isa/rv32mi-p-illegal" # Misaligned LD/ST handling
    )
endif()

foreach(ISA_TEST_BINARY ${ISA_TEST_BINARIES})
    message("Creating ISA test: ${ISA_TEST_BINARY}")
    get_filename_component(TEST_NAME "${ISA_TEST_BINARY}" NAME_WLE)
    message("Test Commandline: ${CMAKE_SOURCE_DIR}/scripts/pg10xsim --check --model ${BUILD_PRESET} --log ${CMAKE_CURRENT_BINARY_DIR}/${TEST_NAME}.trace.txt ${ISA_TEST_BINARY}")
    add_test(
        NAME "ISA_TEST_${TEST_NAME}"
        COMMAND "${CMAKE_SOURCE_DIR}/scripts/pg10xsim" --check --model "${BUILD_PRESET}" --log "${CMAKE_CURRENT_BINARY_DIR}/${TEST_NAME}.trace.txt" "${ISA_TEST_BINARY}"
        WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}"
    )
endforeach()
