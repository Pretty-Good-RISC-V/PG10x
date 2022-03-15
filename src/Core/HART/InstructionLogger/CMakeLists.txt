find_package(spike_disasm)

add_library(InstructionLogger STATIC 
    InstructionLoggerFFI.cpp
    InstructionLoggerFFI.hpp
)
add_library(InstructionLogger::InstructionLogger ALIAS InstructionLogger)

set_target_properties(InstructionLogger PROPERTIES LINKER_LANGUAGE CXX)
set_target_properties(InstructionLogger PROPERTIES CXX_STANDARD 17)

target_include_directories(InstructionLogger PUBLIC "${CMAKE_CURRENT_SOURCE_DIR}")
target_compile_definitions(InstructionLogger PUBLIC ${BASE_ISA})

target_link_libraries(InstructionLogger PUBLIC spike_disasm::spike_disasm)
