add_library(HART2 INTERFACE)
add_library(HART2::HART2 ALIAS HART2)

target_include_directories(HART2 INTERFACE "${CMAKE_CURRENT_SOURCE_DIR}")
target_link_libraries(HART2 INTERFACE
    Common::Common
    CoreCommon::CoreCommon
)

#
# Tests
#
if(ENABLE_SIMULATION)
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
            CoreCommon::CoreCommon
            CSRFile::CSRFile
            TileLink::TileLink
        )
        add_test(
            NAME ${TEST_TARGET}
            COMMAND "${CMAKE_SOURCE_DIR}/cmake/BSV/Wrappers/bsvtest" "${CMAKE_CURRENT_BINARY_DIR}/${TEST_TARGET}" 
        )
    endforeach()
endif()
