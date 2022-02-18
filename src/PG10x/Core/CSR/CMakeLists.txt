add_library(PG10xCoreCSR INTERFACE)
add_library(PG10xCoreCSR::PG10xCoreCSR ALIAS PG10xCoreCSR)

target_include_directories(PG10xCoreCSR INTERFACE "${CMAKE_CURRENT_SOURCE_DIR}")
