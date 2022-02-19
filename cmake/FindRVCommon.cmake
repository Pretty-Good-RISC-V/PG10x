include(FetchContent)

FetchContent_Declare(
    rvcommon
    GIT_REPOSITORY git@github.com:Pretty-Good-RISC-V/RVCommon.git
    GIT_TAG        "main"
)

FetchContent_MakeAvailable(rvcommon)
