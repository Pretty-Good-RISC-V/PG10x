cmake_minimum_required(VERSION 3.21)
list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/cmake")

enable_testing()

project(RISC-V BSV)

option(ENABLE_ISA_TESTS "Enable the RISC-V ISA Architecture Tests" OFF)

add_subdirectory(src)
add_subdirectory(test)
