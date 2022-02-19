cmake_minimum_required(VERSION 3.21)

#
# CMAKE_MODULE_PATH
#
list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/cmake")
list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/cmake/BSV")

enable_testing()

project(RISC-V BSV CXX)

option(ENABLE_ISA_TESTS "Enable the RISC-V ISA Architecture Tests" OFF)

add_subdirectory(src)
add_subdirectory(test)
