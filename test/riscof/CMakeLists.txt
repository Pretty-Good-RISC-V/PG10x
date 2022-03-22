configure_file(config.ini.tmpl "${CMAKE_CURRENT_BINARY_DIR}/config.ini")
configure_file(Makefile.riscof.tmpl "${CMAKE_BINARY_DIR}/Makefile.riscof")

find_program(RISCOF riscof REQUIRED)

add_test(
    NAME riscof_tests
    COMMAND make -f ${CMAKE_BINARY_DIR}/Makefile.riscof
)
