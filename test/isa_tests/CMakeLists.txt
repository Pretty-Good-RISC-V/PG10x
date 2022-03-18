find_package(RISCV_ISA_Tests)

if ("${BASE_ISA}" STREQUAL "RV32")
    set(ISA_TEST_BINARIES
        "${RISCV_ISA_TEST_BUILD_DIR}/src/riscv_isa_tests-build/isa/rv32mi-p-breakpoint" # Breakpoint Tests
        "${RISCV_ISA_TEST_BUILD_DIR}/src/riscv_isa_tests-build/isa/rv32mi-p-csr"        # CSR tests
        "${RISCV_ISA_TEST_BUILD_DIR}/src/riscv_isa_tests-build/isa/rv32mi-p-illegal"    # Illegal instructino traps
        "${RISCV_ISA_TEST_BUILD_DIR}/src/riscv_isa_tests-build/isa/rv32mi-p-ma_addr"    # Misaligned LD/ST handling
        "${RISCV_ISA_TEST_BUILD_DIR}/src/riscv_isa_tests-build/isa/rv32mi-p-ma_fetch"   # Misaligned Fetch handling
        "${RISCV_ISA_TEST_BUILD_DIR}/src/riscv_isa_tests-build/isa/rv32mi-p-mcsr"       # Machine Mode CSR tests
        "${RISCV_ISA_TEST_BUILD_DIR}/src/riscv_isa_tests-build/isa/rv32mi-p-sbreak"     # EBREAK (formerly SBREAK) tests
        "${RISCV_ISA_TEST_BUILD_DIR}/src/riscv_isa_tests-build/isa/rv32mi-p-scall"      # ECALL (formerly SCALL) tests
        "${RISCV_ISA_TEST_BUILD_DIR}/src/riscv_isa_tests-build/isa/rv32mi-p-shamt"      # Illegal shamt tests
    )
endif()

if ("${BASE_ISA}" STREQUAL "RV64")
    set(ISA_TEST_BINARIES
        # "${RISCV_ISA_TEST_BUILD_DIR}/src/riscv_isa_tests-build/isa/rv64mi-p-access"     # Access Exception Tests
        "${RISCV_ISA_TEST_BUILD_DIR}/src/riscv_isa_tests-build/isa/rv64mi-p-breakpoint" # Breakpoint Tests
        "${RISCV_ISA_TEST_BUILD_DIR}/src/riscv_isa_tests-build/isa/rv64mi-p-csr"        # CSR tests
        "${RISCV_ISA_TEST_BUILD_DIR}/src/riscv_isa_tests-build/isa/rv64mi-p-illegal"    # Illegal instructino traps
        "${RISCV_ISA_TEST_BUILD_DIR}/src/riscv_isa_tests-build/isa/rv64mi-p-ma_addr"    # Misaligned LD/ST handling
        "${RISCV_ISA_TEST_BUILD_DIR}/src/riscv_isa_tests-build/isa/rv64mi-p-ma_fetch"   # Misaligned Fetch handling
        "${RISCV_ISA_TEST_BUILD_DIR}/src/riscv_isa_tests-build/isa/rv64mi-p-mcsr"       # Machine Mode CSR tests
        "${RISCV_ISA_TEST_BUILD_DIR}/src/riscv_isa_tests-build/isa/rv64mi-p-sbreak"     # EBREAK (formerly SBREAK) tests
        "${RISCV_ISA_TEST_BUILD_DIR}/src/riscv_isa_tests-build/isa/rv64mi-p-scall"      # ECALL (formerly SCALL) tests
    )
endif()

foreach(ISA_TEST_BINARY ${ISA_TEST_BINARIES})
    message("Creating ISA test: ${ISA_TEST_BINARY}")
    get_filename_component(TEST_NAME "${ISA_TEST_BINARY}" NAME_WLE)
    message("Test Commandline: ${CMAKE_SOURCE_DIR}/scripts/pg10xsim --spike --model ${BUILD_PRESET} --log ${CMAKE_CURRENT_BINARY_DIR}/${TEST_NAME}.trace.txt ${ISA_TEST_BINARY}")
    add_test(
        NAME "ISA_TEST_${TEST_NAME}"
        COMMAND "${CMAKE_SOURCE_DIR}/scripts/pg10xsim" --sim-host src/ISATestHost/ISATestHost --isa "${BASE_ISA}" --spike --check --max-cycles 30000 --model "${BUILD_PRESET}" --log "${CMAKE_CURRENT_BINARY_DIR}/${TEST_NAME}" "${ISA_TEST_BINARY}"
        WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}"
    )
endforeach()
