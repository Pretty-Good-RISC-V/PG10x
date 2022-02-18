#
# FindBlueCheck.cmake
#
# See: https://github.com/CoolpeopleNetworks/bluecheck
#
# Output Variables:
#   BLUECHECK_DIR  - Points to the location of the BSV files of BlueCheck.
#
include(FetchContent)

FetchContent_Declare(
    blue_check
    GIT_REPOSITORY https://github.com/CoolpeopleNetworks/bluecheck.git
    GIT_TAG        "master"
)

FetchContent_MakeAvailable(blue_check)

FetchContent_GetProperties(blue_check SOURCE_DIR BLUECHECK_DIR)

Find_File(BLUECHECK_LIB_DIR 
    NAMES BlueCheck.bsv
    PATHS "${BLUECHECK_DIR}"
    NO_DEFAULT_PATH,
    REQUIRED
)

get_filename_component(BLUECHECK_LIB_DIR ${BLUECHECK_LIB_DIR} DIRECTORY)

add_library(BlueCheck INTERFACE)
add_library(BlueCheck::BlueCheck ALIAS BlueCheck)

target_include_directories(BlueCheck INTERFACE "${BLUECHECK_LIB_DIR}")
