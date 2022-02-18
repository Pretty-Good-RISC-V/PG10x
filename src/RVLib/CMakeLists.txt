add_library(RVLib INTERFACE)
add_library(RVLib::RVLib ALIAS RVLib)

target_include_directories(RVLib INTERFACE "${CMAKE_CURRENT_SOURCE_DIR}")
target_link_libraries(RVLib INTERFACE RVLibCSR)
