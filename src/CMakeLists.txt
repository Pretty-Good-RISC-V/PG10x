find_package(TileLink)
find_package(RVCommon)

add_subdirectory(Common)
add_subdirectory(Core)

if (ENABLE_SIMULATION)
    add_subdirectory(ISATestHost)
    add_subdirectory(Simulator)
    add_subdirectory(Support)
endif()

add_subdirectory(Tiles)

if (NOT ENABLE_SIMULATION)
    add_subdirectory(SoC)
endif()

add_subdirectory(Wrappers)
