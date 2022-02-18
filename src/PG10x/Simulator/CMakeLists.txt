find_package(BlueCheck)

add_executable(PG10xSim Simulator.bsv)
target_link_libraries(PG10xSim 
    PG10xCore::PG10xCore
    RVLib::RVLib
    PGTiles::PGTiles
)

target_compile_definitions(PG10xSim PUBLIC
    ${BASE_ISA}
    ${MONITOR_TOHOST_ADDRESS}
    #DISABLE_BRANCH_PREDICTION
)

#
# Tests
#
add_executable(MemorySystem_tb MemorySystem_tb.bsv)
target_compile_definitions(MemorySystem_tb PUBLIC
    ${BASE_ISA}
    ${MONITOR_TOHOST_ADDRESS}
)
target_link_libraries(MemorySystem_tb
    RVLib::RVLib
    PG10xCore::PG10xCore
    PGTiles::PGTiles
)
add_test(
    NAME MemorySystem_tb
    COMMAND "${CMAKE_SOURCE_DIR}/cmake/Wrappers/bsvtest" "${CMAKE_CURRENT_BINARY_DIR}/MemorySystem_tb" 
    WORKING_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}"
)
