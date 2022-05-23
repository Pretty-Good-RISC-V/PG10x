#
# ISATestHost
#
add_executable(ISATestHost ISATestHost.bsv)
set_target_properties(ISATestHost PROPERTIES LINKER_LANGUAGE BSV)

target_compile_definitions(ISATestHost PUBLIC
    ${BASE_ISA}
)

if (ENABLE_ISA_TESTS)
    target_compile_definitions(ISATestHost PUBLIC
        ENABLE_ISA_TESTS
    )
endif()

target_link_libraries(ISATestHost 
    Core::Core
    Crossbar::Crossbar
    PGRVCommon::PGRVCommon
    Support::Support
)
