find_package(BlueCheck)

#
# Simulator
#
add_executable(Simulator Simulator.bsv)
set_target_properties(Simulator PROPERTIES LINKER_LANGUAGE BSV)

target_link_libraries(Simulator 
    Core::Core
    Crossbar::Crossbar
    RVCommon::RVCommon
    Support::Support
)

target_compile_definitions(Simulator PUBLIC
    ${BASE_ISA}
)

if (ENABLE_RISCOF_TESTS)
    target_compile_definitions(Simulator PUBLIC
        ENABLE_RISCOF_TESTS
    )
endif()

if (NOT ENABLE_BRANCH_PREDICTION)
    target_compile_definitions(Simulator PUBLIC
        DISABLE_BRANCH_PREDICTION
    )
endif()

if (ENABLE_PIPELINING)
    target_compile_definitions(Simulator PUBLIC
        ENABLE_PIPELINING
    )
endif()

if (ENABLE_ISA_TESTS)
    target_compile_definitions(Simulator PUBLIC
        ENABLE_ISA_TESTS
    )
endif()
