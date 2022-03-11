add_subdirectory(Caches)
add_subdirectory(DebugModule)
add_subdirectory(HART)

add_library(PG10xCore INTERFACE)
add_library(PG10xCore::PG10xCore ALIAS PG10xCore)

target_include_directories(PG10xCore INTERFACE "${CMAKE_CURRENT_SOURCE_DIR}")
target_link_libraries(PG10xCore INTERFACE
    HART::HART
    Caches::Caches
    DebugModule::DebugModule
    TileLink::TileLink
)
