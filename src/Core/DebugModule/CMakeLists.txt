add_library(DebugModule INTERFACE)
add_library(DebugModule::DebugModule ALIAS DebugModule)

target_include_directories(DebugModule INTERFACE "${CMAKE_CURRENT_SOURCE_DIR}")
