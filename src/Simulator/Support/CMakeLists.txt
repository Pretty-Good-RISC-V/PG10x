find_package(Catch2 REQUIRED)
find_package(ELFIO REQUIRED)

include(CTest)

add_library(Support STATIC 
    ProgramMemory.cpp
    ProgramMemory.hpp
)
add_library(Support::Support ALIAS Support)

set_target_properties(Support PROPERTIES LINKER_LANGUAGE CXX)
set_target_properties(Support PROPERTIES CXX_STANDARD 17)

target_include_directories(Support PUBLIC "${CMAKE_CURRENT_SOURCE_DIR}")
target_compile_definitions(Support PUBLIC ${BASE_ISA})
target_link_libraries(Support PUBLIC elfio::elfio)

# Find all tests
file(GLOB TEST_FILES "${CMAKE_CURRENT_SOURCE_DIR}/*_test.cpp")
message(">>>>>>>>>>>>>>>>> Found tests: ${TEST_FILES}")
foreach(TEST_FILE ${TEST_FILES})
    get_filename_component(TEST_TARGET ${TEST_FILE} NAME_WLE)
    message("Adding test target ${TEST_TARGET} for ${TEST_FILE}")
    add_executable(${TEST_TARGET} ${TEST_FILE})

    target_link_libraries(${TEST_TARGET} Support Catch2::Catch2WithMain)
    target_compile_definitions(${TEST_TARGET} PUBLIC ${BASE_ISA})
    set_target_properties(${TEST_TARGET} PROPERTIES LINKER_LANGUAGE CXX)
    set_target_properties(${TEST_TARGET} PROPERTIES CXX_STANDARD 17)

    catch_discover_tests(
        ${TEST_TARGET}
        WORKING_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}"
    )
endforeach()

