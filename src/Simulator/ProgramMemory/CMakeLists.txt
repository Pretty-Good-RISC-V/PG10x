find_package(ELFIO REQUIRED)

add_library(ProgramMemory STATIC 
    ProgramMemory.cpp
    ProgramMemory.hpp
)
add_library(ProgramMemory::ProgramMemory ALIAS ProgramMemory)

set_target_properties(ProgramMemory PROPERTIES LINKER_LANGUAGE CXX)
set_target_properties(ProgramMemory PROPERTIES CXX_STANDARD 17)

target_include_directories(ProgramMemory PUBLIC "${CMAKE_CURRENT_SOURCE_DIR}")
target_compile_definitions(ProgramMemory PUBLIC ${BASE_ISA})
target_link_libraries(ProgramMemory PUBLIC elfio::elfio)

add_executable(ProgramMemory_test ProgramMemory_test.cpp)
target_link_libraries(ProgramMemory_test ProgramMemory)
set_target_properties(ProgramMemory_test PROPERTIES LINKER_LANGUAGE CXX)
set_target_properties(ProgramMemory_test PROPERTIES CXX_STANDARD 17)

add_test(
    NAME ProgramMemory_test
    COMMAND "${CMAKE_CURRENT_BINARY_DIR}/ProgramMemory_test" 
    WORKING_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}"
)
