add_subdirectory(CSR)

add_library(PG10xCore INTERFACE)
add_library(PG10xCore::PG10xCore ALIAS PG10xCore)

target_include_directories(PG10xCore INTERFACE "${CMAKE_CURRENT_SOURCE_DIR}")
target_link_libraries(PG10xCore INTERFACE
    PG10xCoreCSR::PG10xCoreCSR
)

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
        RVLib::RVLib
        PG10xCoreCSR::PG10xCoreCSR
    )
    add_test(
        NAME ${TEST_TARGET}
        COMMAND "${CMAKE_SOURCE_DIR}/cmake/Wrappers/bsvtest" "${CMAKE_CURRENT_BINARY_DIR}/${TEST_TARGET}" 
    )
endforeach()
