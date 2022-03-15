add_subdirectory(Core)

add_library(SoC INTERFACE)
add_library(SoC::SoC ALIAS SoC)

target_include_directories(SoC INTERFACE "${CMAKE_CURRENT_SOURCE_DIR}")
target_link_libraries(SoC INTERFACE
    Core::Core
    Crossbar::Crossbar
    TileLink::TileLink
)
