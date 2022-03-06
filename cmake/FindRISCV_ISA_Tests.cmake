include(ExternalProject)

message("Ensuring RISC-V ISA Tests are available")
ExternalProject_Add(riscv_isa_tests
    GIT_REPOSITORY https://github.com/riscv-software-src/riscv-tests.git
    GIT_TAG        "master"
    PREFIX         ${CMAKE_CURRENT_BINARY_DIR}/riscv_isa_tests
    UPDATE_DISCONNECTED true  # need this to avoid constant rebuild
    CONFIGURE_HANDLED_BY_BUILD ON  # avoid constant reconfigure
    CONFIGURE_COMMAND ${CMAKE_CURRENT_BINARY_DIR}/riscv_isa_tests/src/riscv_isa_tests/configure --prefix=${CMAKE_CURRENT_BINARY_DIR}/riscv_isa_tests
    BUILD_COMMAND make
    INSTALL_COMMAND make install
)
message("Ensuring RISC-V ISA Tests are available...complete")

set(RISCV_ISA_TEST_BUILD_DIR ${CMAKE_CURRENT_BINARY_DIR}/riscv_isa_tests CACHE STRING "")
