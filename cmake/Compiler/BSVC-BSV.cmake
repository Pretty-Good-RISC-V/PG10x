# This file sets the basic flags for the BSV compiler
set(CMAKE_BSV_FLAGS_INIT "$ENV{BSVFLAGS} ${CMAKE_BSV_FLAGS_INIT}")

cmake_initialize_per_config_variable(CMAKE_BSV_FLAGS "Flags used by the BSV compiler")
