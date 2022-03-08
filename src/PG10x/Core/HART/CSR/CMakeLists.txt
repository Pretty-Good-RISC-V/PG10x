add_library(CSR INTERFACE)
add_library(CSR::CSR ALIAS CSR)

target_include_directories(CSR INTERFACE "${CMAKE_CURRENT_SOURCE_DIR}")
