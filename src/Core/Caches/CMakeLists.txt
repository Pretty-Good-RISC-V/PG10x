add_library(Caches INTERFACE)
add_library(Caches::Caches ALIAS Caches)

target_include_directories(Caches INTERFACE "${CMAKE_CURRENT_SOURCE_DIR}")
