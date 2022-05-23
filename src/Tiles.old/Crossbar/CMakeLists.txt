add_library(Crossbar INTERFACE)
add_library(Crossbar::Crossbar ALIAS Crossbar)

target_include_directories(Crossbar INTERFACE "${CMAKE_CURRENT_SOURCE_DIR}")
target_link_libraries(Crossbar INTERFACE
    TileLink::TileLink
)
