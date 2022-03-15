add_library(Common INTERFACE)
add_library(Common::Common ALIAS Common)

target_include_directories(Common INTERFACE "${CMAKE_CURRENT_SOURCE_DIR}")
