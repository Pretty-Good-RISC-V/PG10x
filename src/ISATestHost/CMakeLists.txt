#
# ISATestHost
#
add_executable(ISATestHost ISATestHost.bsv)
set_target_properties(ISATestHost PROPERTIES LINKER_LANGUAGE BSV)

target_compile_definitions(ISATestHost PUBLIC
    ${BASE_ISA}
)

if (ENABLE_PIPELINING)
    target_compile_definitions(ISATestHost PUBLIC
        ENABLE_PIPELINING
    )
endif()

if (ENABLE_SIMULATION)
    target_compile_definitions(ISATestHost PUBLIC
        ENABLE_SIMULATION
    )
endif()

target_link_libraries(ISATestHost 
    Core::Core
    Crossbar::Crossbar
    RVCommon::RVCommon
    ProgramMemoryTile::ProgramMemoryTile
)
