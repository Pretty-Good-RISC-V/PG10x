#
# The precompiled RISC-V tests are part of Bluespec's Flute project.
# Download the project here and find the precompiled tests.
#
# RISCV_TESTS_DIR is set to the location where the 'Run_regression.py' script is located.
#
include(FetchContent)

FetchContent_Declare(
    Flute
    GIT_REPOSITORY git@github.com:bluespec/Flute.git
    GIT_TAG        "8a73eeb27607ab49e5e8a4871ad3283387e6ef78"
)

FetchContent_MakeAvailable(Flute)

FetchContent_GetProperties(Flute SOURCE_DIR FLUTE_DIR)

Find_File(RISCV_TESTS_DIR 
    NAMES Run_regression.py
    PATHS "${FLUTE_DIR}" "${FLUTE_DIR}/tests"
    NO_DEFAULT_PATH,
    REQUIRED
)

get_filename_component(RISCV_TESTS_DIR ${RISCV_TESTS_DIR} DIRECTORY)
