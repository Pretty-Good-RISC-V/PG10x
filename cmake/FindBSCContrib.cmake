#
# FindBSCContrib.cmake
#
# See: https://github.com/B-Lang-org/bsc-contrib.git
#
# Output Variables:
#   BSC_CONTRIB_DIR  - Points to the location of the BSV files of bsc-contrib.
#
include(FetchContent)

FetchContent_Declare(
    bsc_contrib
    GIT_REPOSITORY https://github.com/B-Lang-org/bsc-contrib.git
    GIT_TAG        "main"
)

FetchContent_MakeAvailable(bsc_contrib)

FetchContent_GetProperties(bsc_contrib SOURCE_DIR BSC_CONTRIB_DIR)

get_filename_component(BSC_CONTRIB_DIR ${BSC_CONTRIB_DIR} DIRECTORY)

add_library(BSCContrib INTERFACE)
add_library(BSCContrib::BSCContrib ALIAS BSCContrib)

target_include_directories(BSCContrib INTERFACE
    "${BSC_CONTRIB_DIR}/Libraries/Bus"
    "${BSC_CONTRIB_DIR}/Libraries/FPGA/Misc"
)

# Parse components
foreach(_comp IN LISTS BSCContrib_FIND_COMPONENTS)
    if(_comp STREQUAL "XILINX")
        target_include_directories(BSCContrib INTERFACE
            "${BSC_CONTRIB_DIR}/Libraries/FPGA/Xilinx"
        )
    elseif(_comp STREQUAL "ALTERA")
        target_include_directories(BSCContrib INTERFACE
            "${BSC_CONTRIB_DIR}/Libraries/FPGA/Altera"
        )
    elseif(_comp STREQUAL "DDR2")
        target_include_directories(BSCContrib INTERFACE
            "${BSC_CONTRIB_DIR}/Libraries/FPGA/DDR2"        
        )
    elseif(_comp STREQUAL "AMBA_TLM2")
        target_include_directories(BSCContrib INTERFACE
            "${BSC_CONTRIB_DIR}/Libraries/AMBA_TLM2/AHB"
            "${BSC_CONTRIB_DIR}/Libraries/AMBA_TLM2/Axi"
            "${BSC_CONTRIB_DIR}/Libraries/AMBA_TLM2/TLM"
        )
    elseif(_comp STREQUAL "AMBA_TLM3")
        target_include_directories(BSCContrib INTERFACE
            "${BSC_CONTRIB_DIR}/Libraries/AMBA_TLM3/Ahb"
            "${BSC_CONTRIB_DIR}/Libraries/AMBA_TLM3/Apb"
            "${BSC_CONTRIB_DIR}/Libraries/AMBA_TLM3/Axi"
            "${BSC_CONTRIB_DIR}/Libraries/AMBA_TLM3/Axi4"
            "${BSC_CONTRIB_DIR}/Libraries/AMBA_TLM3/TLM3"
        )
    else()
        message(FATAL_ERROR "Unrecognized BSCContrib COMPONENT: ${_comp}")
    endif()
endforeach()
