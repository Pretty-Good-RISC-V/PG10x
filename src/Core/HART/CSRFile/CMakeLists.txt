add_library(CSRFile INTERFACE)
add_library(CSRFile::CSRFile ALIAS CSRFile)

target_include_directories(CSRFile INTERFACE "${CMAKE_CURRENT_SOURCE_DIR}")
target_link_libraries(CSRFile 
    INTERFACE 
    Common::Common
)