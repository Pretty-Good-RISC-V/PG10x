cmake_minimum_required(VERSION 3.21)

#
# CMAKE_MODULE_PATH
#
list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/cmake/BSV")
list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/cmake/pgrv-cmake")

#
# Project
#
project(PG10x BSV CXX)

#
# Build Options
#
option(ENABLE_ISA_TESTS "Enable the RISC-V ISA Architecture Tests" OFF)
option(ENABLE_RISCOF_TESTS "Enable the RISC-V Architecture Tests" OFF)
option(ENABLE_INSTRUCTION_LOGGING "Enable disassembled instruction logging" OFF)
option(ENABLE_S_MODE "Enable supervisor mode inside RISC-V core" OFF)   # NOT IMPLEMENTED

option(ENABLE_BRANCH_PREDICTION "Enable branch prediction inside RISC-V core" ON)
option(ENABLE_PIPELINING "Enable instruction pipelining inside RISC-V core" ON)

option(ENABLE_SOC_VERILOG_OUTPUT "Enable output of Verilog for SoC" OFF)

enable_testing()

add_subdirectory(src)
add_subdirectory(test)
