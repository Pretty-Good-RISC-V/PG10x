add_library(SPIController INTERFACE)
add_library(SPIController::SPIController ALIAS SPIController)

target_include_directories(SPIController INTERFACE "${CMAKE_CURRENT_SOURCE_DIR}")
target_link_libraries(SPIController INTERFACE
    Common::Common
    TileLink::TileLink
)
