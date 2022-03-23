if("${BASE_ISA}" STREQUAL "RV32")
    set(CMAKE_RISCOF_ARCHITECTURE "rv32i_m")
    set(CMAKE_RISCOF_ISA_FILE "pg101_isa.yaml")
elseif("${BASE_ISA}" STREQUAL "RV64")
    set(CMAKE_RISCOF_ARCHITECTURE "rv64i_m")
    set(CMAKE_RISCOF_ISA_FILE "pg103_isa.yaml")
endif()

configure_file(config.ini.tmpl "${CMAKE_CURRENT_BINARY_DIR}/config.ini")
configure_file(Makefile.riscof.tmpl "${CMAKE_BINARY_DIR}/Makefile.riscof")

find_program(RISCOF riscof REQUIRED)

add_test(
    NAME riscof_tests
    COMMAND make -f ${CMAKE_BINARY_DIR}/Makefile.riscof
)
