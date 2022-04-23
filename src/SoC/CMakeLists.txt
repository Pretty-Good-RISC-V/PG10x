add_executable(SoC SoC.bsv)
set_target_properties(SoC PROPERTIES 
    LINKER_LANGUAGE BSV
    RUNTIME_OUTPUT_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}${CMAKE_FILES_DIRECTORY}/SoC.dir"
    RUNTIME_OUTPUT_NAME mkSoC.v
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

install(TARGETS SoC
#    "${CMAKE_CURRENT_BINARY_DIR}/mkSoC.v"
    RUNTIME
        DESTINATION "verilog"
)
