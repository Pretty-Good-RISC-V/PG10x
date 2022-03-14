add_subdirectory(Caches)
add_subdirectory(DebugModule)
add_subdirectory(HART)

add_library(Core INTERFACE)
add_library(Core::Core ALIAS Core)

target_include_directories(Core INTERFACE "${CMAKE_CURRENT_SOURCE_DIR}")
target_link_libraries(Core INTERFACE
    HART::HART
    Caches::Caches
    DebugModule::DebugModule
    TileLink::TileLink
)
