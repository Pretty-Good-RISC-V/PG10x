include(CMakeLanguageInformation)

# Load compiler-specific information.
if(CMAKE_BSV_COMPILER_ID)
  include(Compiler/${CMAKE_BSV_COMPILER_ID}-BSV)
endif()

include(CMakeCommonLanguageInclude)

set(CMAKE_BSV_OUTPUT_EXTENSION .bo)
set(CMAKE_INCLUDE_FLAG_BSV "-I ")

if(NOT CMAKE_BSV_COMPILE_OBJECT)
    set(CMAKE_BSV_COMPILE_OBJECT 
        "<CMAKE_BSV_COMPILER> -o <OBJECT> <DEFINES> <INCLUDES> <SOURCE>"
    )
endif()

if(NOT CMAKE_BSV_LINK_EXECUTABLE)
    set(CMAKE_BSV_LINK_EXECUTABLE 
        "<CMAKE_BSV_LINKER> -v <FLAGS> <OBJECTS> -o <TARGET> <LINK_LIBRARIES>"
    )
endif()

set(CMAKE_BSV_INFORMATION_LOADED 1)
