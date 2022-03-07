add_subdirectory(CPU)

add_library(PG10xCore INTERFACE)
add_library(PG10xCore::PG10xCore ALIAS PG10xCore)

#target_include_directories(PG10xCore INTERFACE "${CMAKE_CURRENT_SOURCE_DIR}")
target_link_libraries(PG10xCore INTERFACE
    PG10xCPU::PG10xCPU
    TileLink::TileLink
)
