#
# ISATestHost
#
add_executable(ISATestHost ISATestHost.bsv)
set_target_properties(ISATestHost PROPERTIES LINKER_LANGUAGE BSV)

target_compile_definitions(ISATestHost PUBLIC
    ${BASE_ISA}
    ${MONITOR_TOHOST_ADDRESS}
)

target_link_libraries(ISATestHost 
    Core::Core
    Crossbar::Crossbar
    RVCommon::RVCommon
    Support::Support
)
