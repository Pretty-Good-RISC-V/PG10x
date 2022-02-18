add_subdirectory(Caches)

add_library(PGTiles INTERFACE)
add_library(PGTiles::PGTiles ALIAS PGTiles)

target_include_directories(PGTiles INTERFACE "${CMAKE_CURRENT_SOURCE_DIR}")
target_link_libraries(PGTiles INTERFACE 
    TileLink::TileLink
)
