include(FetchContent)

FetchContent_Declare(
    rvcommon
    GIT_REPOSITORY git@github.com:Pretty-Good-RISC-V/RVCommon.git
    GIT_TAG        "main"
)

message("Ensuring RVCommon is available")
FetchContent_MakeAvailable(rvcommon)
message("Ensuring RVCommon is available...complete")
