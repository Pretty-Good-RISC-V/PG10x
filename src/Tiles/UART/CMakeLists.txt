if (NOT ENABLE_SIMULATION)
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
        target_compile_definitions(${TEST_TARGET} PUBLIC
            ${BASE_ISA}
        )
        target_compile_options(${TEST_TARGET} PRIVATE 
            --verilog
        )
        target_link_options(${TEST_TARGET} PRIVATE 
            --verilog
        )
        target_link_libraries(${TEST_TARGET}
            RVCommon::RVCommon
            Common::Common
            TileLink::TileLink
        )
    endforeach()
endif()
