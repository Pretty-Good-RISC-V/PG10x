add_subdirectory(CSRFile)

add_library(CoreCommon INTERFACE)
add_library(CoreCommon::CoreCommon ALIAS CoreCommon)

target_include_directories(CoreCommon INTERFACE "${CMAKE_CURRENT_SOURCE_DIR}")
target_link_libraries(CoreCommon 
    INTERFACE 
    Common::Common
    CSRFile::CSRFile
)
