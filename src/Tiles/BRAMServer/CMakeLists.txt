add_library(BRAMServerTile INTERFACE)
add_library(BRAMServerTile::BRAMServerTile ALIAS BRAMServerTile)

target_include_directories(BRAMServerTile INTERFACE "${CMAKE_CURRENT_SOURCE_DIR}")
target_link_libraries(BRAMServerTile INTERFACE 
    TileLink::TileLink
)
