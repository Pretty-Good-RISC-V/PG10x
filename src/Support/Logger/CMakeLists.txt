find_package(spike_disasm)

add_library(Logger STATIC 
    InstructionLoggerFFI.cpp
    InstructionLoggerFFI.hpp
)
add_library(Logger::Logger ALIAS Logger)

set_target_properties(Logger PROPERTIES LINKER_LANGUAGE CXX)
set_target_properties(Logger PROPERTIES CXX_STANDARD 17)

target_include_directories(Logger PUBLIC "${CMAKE_CURRENT_SOURCE_DIR}")
target_compile_definitions(Logger PUBLIC ${BASE_ISA})

target_link_libraries(Logger 
    PUBLIC
        Common::Common 
        spike_disasm::spike_disasm
)
