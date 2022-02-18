add_library(TileLink INTERFACE)
add_library(TileLink::TileLink ALIAS TileLink)

target_include_directories(TileLink INTERFACE "${CMAKE_CURRENT_SOURCE_DIR}")
