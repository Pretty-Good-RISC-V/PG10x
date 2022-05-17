find_package(Catch2 REQUIRED)
find_package(ELFIO REQUIRED)

include(CTest)

add_library(ProgramMemoryTile STATIC 
    ProgramMemory.cpp
    ProgramMemory.hpp
)
add_library(ProgramMemoryTile::ProgramMemoryTile ALIAS ProgramMemoryTile)

set_target_properties(ProgramMemoryTile PROPERTIES LINKER_LANGUAGE CXX)
set_target_properties(ProgramMemoryTile PROPERTIES CXX_STANDARD 17)
set_target_properties(ProgramMemoryTile PROPERTIES POSITION_INDEPENDENT_CODE ON)

target_include_directories(ProgramMemoryTile PUBLIC "${CMAKE_CURRENT_SOURCE_DIR}")
target_compile_definitions(ProgramMemoryTile PUBLIC ${BASE_ISA})
target_link_libraries(ProgramMemoryTile PUBLIC Common::Common elfio::elfio)

# Find all tests
file(GLOB TEST_FILES "${CMAKE_CURRENT_SOURCE_DIR}/*_test.cpp")
foreach(TEST_FILE ${TEST_FILES})
    get_filename_component(TEST_TARGET ${TEST_FILE} NAME_WLE)
    add_executable(${TEST_TARGET} ${TEST_FILE})

    target_link_libraries(${TEST_TARGET} ProgramMemoryTile Common::Common Catch2::Catch2WithMain)
    target_compile_definitions(${TEST_TARGET} PUBLIC ${BASE_ISA})
    set_target_properties(${TEST_TARGET} PROPERTIES LINKER_LANGUAGE CXX)
    set_target_properties(${TEST_TARGET} PROPERTIES CXX_STANDARD 17)

    catch_discover_tests(
        ${TEST_TARGET}
        WORKING_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}"
    )
endforeach()

