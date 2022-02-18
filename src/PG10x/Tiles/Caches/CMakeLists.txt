add_library(PGCaches INTERFACE)
add_library(PGCaches::PGCaches ALIAS PGCaches)

target_include_directories(PGCaches INTERFACE "${CMAKE_CURRENT_SOURCE_DIR}")
