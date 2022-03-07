add_subdirectory(CSR)
add_subdirectory(InstructionLogger)

add_library(PG10xCPU INTERFACE)
add_library(PG10xCPU::PG10xCPU ALIAS PG10xCPU)

target_include_directories(PG10xCPU INTERFACE "${CMAKE_CURRENT_SOURCE_DIR}")
target_link_libraries(PG10xCPU INTERFACE
    PG10xCSR::PG10xCSR
    TileLink::TileLink
)

if (ENABLE_INSTRUCTION_LOGGING)
    target_link_libraries(PG10xCPU INTERFACE
        InstructionLogger::InstructionLogger
    )
    target_compile_definitions(PG10xCPU INTERFACE
        ENABLE_INSTRUCTION_LOGGING
    )
endif()

#
# Tests
#
file(GLOB TEST_FILES "${CMAKE_CURRENT_SOURCE_DIR}/*_tb.bsv")
foreach(TEST_FILE ${TEST_FILES})
    get_filename_component(TEST_TARGET ${TEST_FILE} NAME_WE)
    add_executable(${TEST_TARGET} ${TEST_FILE})
    target_compile_definitions(${TEST_TARGET} PUBLIC
        ${BASE_ISA}
    )
    target_link_libraries(${TEST_TARGET}
        RVCommon::RVCommon
        PG10xCSR::PG10xCSR
        TileLink::TileLink
    )
    add_test(
        NAME ${TEST_TARGET}
        COMMAND "${CMAKE_SOURCE_DIR}/cmake/BSV/Wrappers/bsvtest" "${CMAKE_CURRENT_BINARY_DIR}/${TEST_TARGET}" 
    )
endforeach()
