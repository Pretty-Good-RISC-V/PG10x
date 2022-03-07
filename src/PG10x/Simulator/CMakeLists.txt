find_package(BlueCheck)

#
# Simulator
#
add_executable(Simulator Simulator.bsv)
set_target_properties(Simulator PROPERTIES LINKER_LANGUAGE BSV)

target_link_libraries(Simulator 
    PG10xCPU::PG10xCPU
    RVCommon::RVCommon
    PGTiles::PGTiles
)

target_compile_definitions(Simulator PUBLIC
    ${BASE_ISA}
    ${MONITOR_TOHOST_ADDRESS}
)

if (NOT ENABLE_BRANCH_PREDICTION)
    target_compile_definitions(Simulator PUBLIC
        DISABLE_BRANCH_PREDICTION
    )
endif()

if (NOT ENABLE_PIPELINING)
    target_compile_definitions(Simulator PUBLIC
        DISABLE_PIPELINING
    )
endif()
