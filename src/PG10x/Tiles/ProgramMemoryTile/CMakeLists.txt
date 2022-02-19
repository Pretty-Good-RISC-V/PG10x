find_package(ELFIO REQUIRED)

set(SOURCES
    ProgramMemory.cpp
)

add_library(ProgramMemoryTile STATIC ${SOURCES})
add_library(ProgramMemoryTile::ProgramMemoryTile ALIAS ProgramMemoryTile)

set_target_properties(ProgramMemoryTile PROPERTIES LINKER_LANGUAGE CXX)
set_target_properties(ProgramMemoryTile PROPERTIES CXX_STANDARD 17)

target_include_directories(ProgramMemoryTile PUBLIC "${CMAKE_CURRENT_SOURCE_DIR}")
target_compile_definitions(ProgramMemoryTile PUBLIC ${BASE_ISA})
target_link_libraries(ProgramMemoryTile PUBLIC elfio::elfio)

add_custom_target(ProgramMemory_Test_Inpput
    COMMAND cmake 
    ${CMAKE_CURRENT_SOURCE_DIR}/TestSource
)