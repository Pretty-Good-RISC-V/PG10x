add_executable(SoC SoC.bsv)
set_target_properties(SoC PROPERTIES 
    LINKER_LANGUAGE BSV
)

target_compile_definitions(SoC PUBLIC
    ${BASE_ISA}
)

target_compile_options(SoC PRIVATE 
    --verilog
)

target_link_options(SoC PRIVATE 
    --verilog
)

if (ENABLE_PIPELINING)
    target_compile_definitions(SoC PUBLIC
        ENABLE_PIPELINING
    )
endif()

target_link_libraries(SoC 
    Core::Core
    Crossbar::Crossbar
    RVCommon::RVCommon
    SPIController::SPIController
    UARTTile::UARTTile
)

find_program(BSC_PATH
    bsc
    REQUIRED
)

cmake_path(GET BSC_PATH PARENT_PATH BSC_ROOT)
cmake_path(GET BSC_ROOT PARENT_PATH BSC_ROOT)

set(SOC_VERILOG_FILES
    "${CMAKE_CURRENT_BINARY_DIR}/mkALU.v"
    "${CMAKE_CURRENT_BINARY_DIR}/mkBackwardBranchTakenPredictor.v"
    "${CMAKE_CURRENT_BINARY_DIR}/mkGPRFile.v"
    "${CMAKE_CURRENT_BINARY_DIR}/mkSoC.v"
    "${CMAKE_CURRENT_BINARY_DIR}/mkTransmitter.v"
    "${CMAKE_CURRENT_BINARY_DIR}/mkUART.v"

    "${BSC_ROOT}/lib/Verilog/Counter.v"
    "${BSC_ROOT}/lib/Verilog/FIFO2.v"
    "${BSC_ROOT}/lib/Verilog/GatedClock.v"
    "${BSC_ROOT}/lib/Verilog/RegFile.v"
    "${BSC_ROOT}/lib/Verilog/SizedFIFO.v"
    "${BSC_ROOT}/lib/Verilog/SyncFIFO.v"
    "${BSC_ROOT}/lib/Verilog/SyncReset.v"
    "${BSC_ROOT}/lib/Verilog/SyncResetA.v"
)

foreach(SOC_VERILOG_FILE ${SOC_VERILOG_FILES})
    install(FILES
        "${SOC_VERILOG_FILE}"
        DESTINATION "verilog"
    )
endforeach()
