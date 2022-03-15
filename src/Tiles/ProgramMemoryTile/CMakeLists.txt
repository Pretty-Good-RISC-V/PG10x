add_library(ProgramMemoryTile INTERFACE)
add_library(ProgramMemoryTile::ProgramMemoryTile ALIAS ProgramMemoryTile)

target_include_directories(ProgramMemoryTile INTERFACE "${CMAKE_CURRENT_SOURCE_DIR}")
target_link_libraries(ProgramMemoryTile INTERFACE 
    ProgramMemory::ProgramMemory
    TileLink::TileLink
)
