find_package(ELFIO REQUIRED)

add_library(ProgramMemoryTile STATIC 
    ProgramMemory.cpp
    ProgramMemory.hpp
)
add_library(ProgramMemoryTile::ProgramMemoryTile ALIAS ProgramMemoryTile)

set_target_properties(ProgramMemoryTile PROPERTIES LINKER_LANGUAGE CXX)
set_target_properties(ProgramMemoryTile PROPERTIES CXX_STANDARD 17)

target_include_directories(ProgramMemoryTile PUBLIC "${CMAKE_CURRENT_SOURCE_DIR}")
target_compile_definitions(ProgramMemoryTile PUBLIC ${BASE_ISA})
target_link_libraries(ProgramMemoryTile PUBLIC elfio::elfio)

add_executable(ProgramMemory_test ProgramMemory_test.cpp)
target_link_libraries(ProgramMemory_test ProgramMemoryTile)
set_target_properties(ProgramMemory_test PROPERTIES LINKER_LANGUAGE CXX)
set_target_properties(ProgramMemory_test PROPERTIES CXX_STANDARD 17)

add_test(
    NAME ProgramMemory_test
    COMMAND "${CMAKE_CURRENT_BINARY_DIR}/ProgramMemory_test" "./test_assets/rv32mi-p-csr" 
    WORKING_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}"
)
