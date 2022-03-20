configure_file(config.ini.tmpl "${CMAKE_CURRENT_BINARY_DIR}/config.ini")

add_custom_target(riscof_setup
    ALL
    COMMAND "riscof --verbose info arch-test --clone"
)

add_test(
    NAME riscof_tests
    COMMAND "riscof --verbose info run --config ${CMAKE_CURRENT_SOURCE_DIR}/config.ini --suite ${CMAKE_CURRENT_BINARY_DIR}/riscv-arch-test/riscv-test-suite/rv32i_m --env ${CMAKE_CURRENT_BINARY_DIR}/riscv-arch-test/riscv-test-suite/env"
    DEPENDS Simulator riscof_setup
)
