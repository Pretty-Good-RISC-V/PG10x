#
# FindConnectal.cmake
#
# See: https://github.com/cambridgehackers/connectal.git
#
# Output Variables:
#   CONNECTAL_LIB_DIR  - Points to the location of the BSV files of Connectal.
#
include(FetchContent)

FetchContent_Declare(
    connectal
    GIT_REPOSITORY https://github.com/cambridgehackers/connectal.git
    GIT_TAG        "master"
)

FetchContent_MakeAvailable(connectal)

FetchContent_GetProperties(connectal SOURCE_DIR CONNECTAL_DIR)

Find_File(CONNECTAL_LIB_DIR 
    NAMES Adapter.bsv
    PATHS "${CONNECTAL_DIR}" "${CONNECTAL_DIR}/bsv"
    NO_DEFAULT_PATH,
    REQUIRED
)

get_filename_component(CONNECTAL_LIB_DIR ${CONNECTAL_LIB_DIR} DIRECTORY)

add_library(Connectal INTERFACE)
add_library(Connectal::Connectal ALIAS Connectal)

target_include_directories(Connectal INTERFACE "${CONNECTAL_LIB_DIR}")
