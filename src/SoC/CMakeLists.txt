add_executable(SoC SoC.bsv)
set_target_properties(SoC PROPERTIES LINKER_LANGUAGE BSV)

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
