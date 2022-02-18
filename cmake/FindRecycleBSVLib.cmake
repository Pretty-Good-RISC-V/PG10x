#
# FindRecycleBSVLib.cmake
#
# See: https://github.com/csail-csg/recycle-bsv-lib.git
#
# Output Variables:
#   RECYCLE_BSV_LIB_DIR  - Points to the location of the BSV files of Recycle-BSV-Lib.
#
include(FetchContent)

FetchContent_Declare(
    recycle_bsv_lib
    GIT_REPOSITORY https://github.com/csail-csg/recycle-bsv-lib.git
    GIT_TAG        "master"
)

FetchContent_MakeAvailable(recycle_bsv_lib)

FetchContent_GetProperties(recycle_bsv_lib SOURCE_DIR RECYCLE_BSV_DIR)

Find_File(RECYCLE_BSV_LIB_DIR 
    NAMES ClientServerUtil.bsv
    PATHS "${RECYCLE_BSV_DIR}" "${RECYCLE_BSV_DIR}/src/bsv"
    NO_DEFAULT_PATH,
    REQUIRED
)

get_filename_component(RECYCLE_BSV_LIB_DIR ${RECYCLE_BSV_LIB_DIR} DIRECTORY)

add_library(RecycleBSVLib INTERFACE)
add_library(RecycleBSVLib::RecycleBSVLib ALIAS RecycleBSVLib)

target_include_directories(RecycleBSVLib INTERFACE "${RECYCLE_BSV_LIB_DIR}")
