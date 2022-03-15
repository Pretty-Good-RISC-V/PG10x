add_subdirectory(CSRFile)
add_subdirectory(InstructionLogger)

add_library(HART INTERFACE)
add_library(HART::HART ALIAS HART)

target_include_directories(HART INTERFACE "${CMAKE_CURRENT_SOURCE_DIR}")
target_link_libraries(HART INTERFACE
    Common::Common
    CSRFile::CSRFile
    TileLink::TileLink
)

if (ENABLE_INSTRUCTION_LOGGING)
    target_link_libraries(HART INTERFACE
        InstructionLogger::InstructionLogger
    )
    target_compile_definitions(HART INTERFACE
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
        Common::Common
        CSRFile::CSRFile
        TileLink::TileLink
    )
    add_test(
        NAME ${TEST_TARGET}
        COMMAND "${CMAKE_SOURCE_DIR}/cmake/BSV/Wrappers/bsvtest" "${CMAKE_CURRENT_BINARY_DIR}/${TEST_TARGET}" 
    )
endforeach()
