include(FetchContent)

FetchContent_Declare(
    Catch2
    GIT_REPOSITORY https://github.com/catchorg/Catch2.git
    GIT_TAG        "v2.x"
)

message("Ensuring Catch2 is available")
FetchContent_MakeAvailable(Catch2)
message("Ensuring Catch2 is available...complete")
