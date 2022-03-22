configure_file(config.ini.tmpl "${CMAKE_CURRENT_BINARY_DIR}/config.ini")

find_program(RISCOF riscof REQUIRED)

add_test(
    NAME riscof_setup
    COMMAND ${RISCOF} --verbose info arch-test --clone
)

add_test(
    NAME riscof_tests
    COMMAND ${RISCOF} --verbose info run --config ${CMAKE_CURRENT_BINARY_DIR}/config.ini --suite ${CMAKE_CURRENT_BINARY_DIR}/riscv-arch-test/riscv-test-suite/rv32i_m --env ${CMAKE_CURRENT_BINARY_DIR}/riscv-arch-test/riscv-test-suite/env
)
