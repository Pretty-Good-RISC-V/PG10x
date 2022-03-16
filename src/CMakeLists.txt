find_package(TileLink)
find_package(RVCommon)

add_subdirectory(Common)
add_subdirectory(Core)

if(ENABLE_ISA_TESTS)
    add_subdirectory(ISATestHost)
endif()

add_subdirectory(SoC)
add_subdirectory(Simulator)
add_subdirectory(Support)
add_subdirectory(Tiles)
