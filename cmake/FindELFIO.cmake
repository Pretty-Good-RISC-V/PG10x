include(FetchContent)

FetchContent_Declare(
    ELFIO
    GIT_REPOSITORY https://github.com/serge1/ELFIO.git
    GIT_TAG        "Release_3.10"
)

message("Ensuring ELFIO is available")
FetchContent_MakeAvailable(ELFIO)
message("Ensuring ELFIO is available...complete")
