add_library(CSRFile INTERFACE)
add_library(CSRFile::CSRFile ALIAS CSRFile)

target_include_directories(CSRFile INTERFACE "${CMAKE_CURRENT_SOURCE_DIR}")
