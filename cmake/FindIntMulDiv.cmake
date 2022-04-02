include(FetchContent)

FetchContent_Declare(
    intmuldiv
    GIT_REPOSITORY git@github.com:Pretty-Good-RISC-V/IntMulDiv.git
    GIT_TAG        "main"
)

message("Ensuring IntMulDiv is available")
FetchContent_MakeAvailable(intmuldiv)
message("Ensuring IntMulDiv is available...complete")
