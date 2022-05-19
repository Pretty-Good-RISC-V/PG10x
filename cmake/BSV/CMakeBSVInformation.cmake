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
        "<CMAKE_BSV_COMPILER> --link <FLAGS> <OBJECTS> -o <TARGET> <LINK_LIBRARIES>"
    )
endif()

set(CMAKE_BSV_INFORMATION_LOADED 1)

# Get all propreties that cmake supports
if(NOT CMAKE_PROPERTY_LIST)
    execute_process(COMMAND cmake --help-property-list OUTPUT_VARIABLE CMAKE_PROPERTY_LIST)
    
    # Convert command output into a CMake list
    string(REGEX REPLACE ";" "\\\\;" CMAKE_PROPERTY_LIST "${CMAKE_PROPERTY_LIST}")
    string(REGEX REPLACE "\n" ";" CMAKE_PROPERTY_LIST "${CMAKE_PROPERTY_LIST}")
endif()
    
function(print_properties)
    message("CMAKE_PROPERTY_LIST = ${CMAKE_PROPERTY_LIST}")
endfunction()
    
function(print_target_properties target)
    if(NOT TARGET ${target})
      message(STATUS "There is no target named '${target}'")
      return()
    endif()

    foreach(property ${CMAKE_PROPERTY_LIST})
        string(REPLACE "<CONFIG>" "${CMAKE_BUILD_TYPE}" property ${property})

        # Fix https://stackoverflow.com/questions/32197663/how-can-i-remove-the-the-location-property-may-not-be-read-from-target-error-i
        if(property STREQUAL "LOCATION" OR property MATCHES "^LOCATION_" OR property MATCHES "_LOCATION$")
            continue()
        endif()

        get_property(was_set TARGET ${target} PROPERTY ${property} SET)
        if(was_set)
            get_target_property(value ${target} ${property})
            message("${target} ${property} = ${value}")
        endif()
    endforeach()
endfunction()

function(resolve_dependencies target)
    set(ALL_LINK_LIBRARIES "")

    # Get the current INTERFACE_LINK_LIBRARIES from the ${target}
    get_target_property(DIRECT_DEPENDENCIES ${target} INTERFACE_LINK_LIBRARIES)

    # Loop through all *direct* dependencies and ensure they've been updated.   
    # Then, add that dependency's dependencies to the current list
    if (NOT "${DIRECT_DEPENDENCIES}" STREQUAL "DIRECT_DEPENDENCIES-NOTFOUND")
        # Direct dependencies
        foreach(DIRECT_DEPENDENCY ${DIRECT_DEPENDENCIES})
            # See if the dependency is already in the list, if not, recurse.
            list(FIND ALL_LINK_LIBRARIES ${DIRECT_DEPENDENCY} FOUND_ITEM)
            if (FOUND_ITEM EQUAL -1)
                list(APPEND ALL_LINK_LIBRARIES ${DIRECT_DEPENDENCY})
                resolve_dependencies(${DIRECT_DEPENDENCY})

                get_target_property(DIRECT_DEPENDENCY_RESOLVED_LINK_LIBRARIES ${DIRECT_DEPENDENCY} RESOLVED_LINK_LIBRARIES)
                set(ALL_LINK_LIBRARIES "${ALL_LINK_LIBRARIES};${DIRECT_DEPENDENCY_RESOLVED_LINK_LIBRARIES}")
            endif()
        endforeach()
    endif()

    # Save the resolved library list into the target
    list(REMOVE_DUPLICATES ALL_LINK_LIBRARIES)
    get_target_property(TARGET_TO_UPDATE ${target} ALIASED_TARGET)
    if ("${TARGET_TO_UPDATE}" STREQUAL "")
        set(TARGET_TO_UPDATE ${target})
    endif()
    set_target_properties(${TARGET_TO_UPDATE} PROPERTIES RESOLVED_LINK_LIBRARIES "${ALL_LINK_LIBRARIES}")
endfunction()

function(add_bsv_verilog_module target modulefile)
    # First, enumerate all given dependencies and resolve all of their dependencies.
    # These resolved dependencies will be used to determine the include directories
    # that will be given to the BSV compiler.
    set(RESOLVED_DEPENDENCIES "")
    foreach(dependency ${ARGN})
        if (NOT TARGET ${dependency})
            message(FATAL_ERROR "add_bsv_verilog_module: TARGET ${dependency} not found")
            return()
        endif()

        list(APPEND RESOLVED_DEPENDENCIES ${dependency})

        resolve_dependencies(${dependency})
        get_target_property(RESOLVED_LINK_LIBRARIES ${dependency} RESOLVED_LINK_LIBRARIES)

#        message("++++++++ DIRECT_DEPENDENCY: ${dependency} - ${RESOLVED_LINK_LIBRARIES}")
        list(APPEND RESOLVED_DEPENDENCIES ${RESOLVED_LINK_LIBRARIES})
    endforeach()

    list(REMOVE_DUPLICATES RESOLVED_DEPENDENCIES)
#    message("++++++++++ All deps: '${RESOLVED_DEPENDENCIES}'")

    # Next, go through each of the dependencies given and extract the INTERFACE_INCLUDE_DIRECTORIES.
    # The directories found are then added to DEPENDENCY_DIRS (which is then given to the BSV compiler)
    set(DEPENDENCY_DIRS "%/Libraries")

    foreach(dependency ${RESOLVED_DEPENDENCIES})
        if (NOT TARGET ${dependency})
            message(FATAL_ERROR "add_bsv_verilog_module: TARGET ${dependency} not found")
            return()
        endif()
        get_target_property(DEPENDENCY_DIR ${dependency} INTERFACE_INCLUDE_DIRECTORIES)
        list(APPEND DEPENDENCY_DIRS "${DEPENDENCY_DIR}")
    endforeach()

    list(JOIN DEPENDENCY_DIRS ":" DEPENDENCY_DIRS_STRING)

    get_filename_component(module ${modulefile} NAME_WLE)
    add_custom_target(${target}
        ALL
        COMMAND bsc -verilog -vdir ${CMAKE_CURRENT_BINARY_DIR} -bdir ${CMAKE_CURRENT_BINARY_DIR} -fdir ${CMAKE_CURRENT_BINARY_DIR} -info-dir ${CMAKE_CURRENT_BINARY_DIR} -D ${BASE_ISA} -g mk${module} -u -p "${DEPENDENCY_DIRS_STRING}" "${CMAKE_CURRENT_SOURCE_DIR}/${modulefile}"
        DEPENDS ${ARGN}
    )
endfunction()
