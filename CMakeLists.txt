cmake_minimum_required(VERSION 3.21)

#
# CMAKE_MODULE_PATH
#
list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/cmake")
list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/cmake/BSV")

#
# Project
#
project(PG10x BSV CXX)

#
# Build Options
#
option(ENABLE_ISA_TESTS "Enable the RISC-V ISA Architecture Tests" OFF)
option(ENABLE_BRANCH_PREDICTION "Enable branch prediction inside RISC-V Core" ON)

enable_testing()

add_subdirectory(src)
add_subdirectory(test)
