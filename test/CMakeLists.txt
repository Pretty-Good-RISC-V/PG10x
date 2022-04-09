add_subdirectory(smoke_tests)

if(ENABLE_ISA_TESTS)
    add_subdirectory(isa_tests)
endif()

if (ENABLE_RISCOF_TESTS)
    add_subdirectory(riscof)
endif()
