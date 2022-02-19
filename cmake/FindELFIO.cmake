include(FetchContent)

FetchContent_Declare(
    ELFIO
    GIT_REPOSITORY https://github.com/serge1/ELFIO.git
    GIT_TAG        "Release_3.10"
)

FetchContent_MakeAvailable(ELFIO)
