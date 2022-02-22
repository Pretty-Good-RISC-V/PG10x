find_package(BlueCheck)

#
# Simulator
#
add_executable(Simulator Simulator.bsv)
set_target_properties(Simulator PROPERTIES LINKER_LANGUAGE BSV)

target_link_libraries(Simulator 
    PG10xCore::PG10xCore
    RVCommon::RVCommon
    PGTiles::PGTiles
)

target_compile_definitions(Simulator PUBLIC
    ${BASE_ISA}
    ${MONITOR_TOHOST_ADDRESS}
)

if(!ENABLE_BRANCH_PREDICTION)
    target_compile_definitions(Simulator PUBLIC
        DISABLE_BRANCH_PREDICTION
    )
endif()

#
# Tests
#
add_executable(MemorySystem_tb MemorySystem_tb.bsv)
target_compile_definitions(MemorySystem_tb PUBLIC
    ${BASE_ISA}
    ${MONITOR_TOHOST_ADDRESS}
)

target_link_libraries(MemorySystem_tb
    RVCommon::RVCommon
    PG10xCore::PG10xCore
    PGTiles::PGTiles
)

add_test(
    NAME MemorySystem_tb
    COMMAND "${CMAKE_SOURCE_DIR}/cmake/BSV/Wrappers/bsvtest" "${CMAKE_CURRENT_BINARY_DIR}/MemorySystem_tb" 
    WORKING_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}"
)
