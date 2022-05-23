add_library(ROMServerTile INTERFACE)
add_library(ROMServerTile::ROMServerTile ALIAS ROMServerTile)

target_include_directories(ROMServerTile INTERFACE "${CMAKE_CURRENT_SOURCE_DIR}")
target_link_libraries(ROMServerTile INTERFACE 
    TileLink::TileLink
)
