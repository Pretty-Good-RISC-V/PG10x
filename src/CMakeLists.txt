find_package(TileLink)
find_package(RVCommon)

add_subdirectory(Common)
add_subdirectory(Core)

if(ENABLE_ISA_TESTS)
    add_subdirectory(ISATestHost)
endif()

if (NOT ENABLE_SOC_VERILOG_OUTPUT)
    add_subdirectory(Simulator)
    add_subdirectory(Support)
endif()

add_subdirectory(Tiles)

if (ENABLE_SOC_VERILOG_OUTPUT)
    add_subdirectory(SoC)
endif()

add_subdirectory(Wrappers)
