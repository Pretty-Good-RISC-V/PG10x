add_library(UARTTile INTERFACE)
add_library(UARTTile::UARTTile ALIAS UARTTile)

target_include_directories(UARTTile INTERFACE "${CMAKE_CURRENT_SOURCE_DIR}")
target_link_libraries(UARTTile INTERFACE
    Common::Common
    TileLink::TileLink
)

#
# Tests
#
file(GLOB TEST_FILES "${CMAKE_CURRENT_SOURCE_DIR}/*_tb.bsv")
foreach(TEST_FILE ${TEST_FILES})
    get_filename_component(TEST_TARGET ${TEST_FILE} NAME_WE)

    add_executable(${TEST_TARGET} ${TEST_FILE})

    if(NOT ENABLE_SIMULATION)
        set_target_properties(${TEST_TARGET} PROPERTIES 
            LINKER_LANGUAGE BSV
            RUNTIME_OUTPUT_NAME mk${TEST_TARGET}.v
        )

        target_compile_options(${TEST_TARGET} PRIVATE 
            --verilog
        )
        target_link_options(${TEST_TARGET} PRIVATE 
            --verilog
        )
    else()
        target_compile_definitions(${TEST_TARGET} PUBLIC
            ENABLE_SIMULATION
        )
    endif()
    
    target_compile_definitions(${TEST_TARGET} PUBLIC
        ${BASE_ISA}
    )
    target_link_libraries(${TEST_TARGET}
        RVCommon::RVCommon
        Common::Common
        TileLink::TileLink
    )

    # if (ENABLE_SIMULATION)
    #     add_test(
    #         NAME ${TEST_TARGET}
    #         COMMAND "${CMAKE_SOURCE_DIR}/cmake/BSV/Wrappers/bsvtest" "${CMAKE_CURRENT_BINARY_DIR}/${TEST_TARGET}" 
    #     )
    # endif()
endforeach()

if (NOT ENABLE_SIMULATION)
    install(FILES
        "${CMAKE_CURRENT_BINARY_DIR}/mkTransmitter_tb.v"
        DESTINATION "verilog"
    )
endif()
