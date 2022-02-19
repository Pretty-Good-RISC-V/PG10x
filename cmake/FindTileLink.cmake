include(FetchContent)

FetchContent_Declare(
    tilelink
    GIT_REPOSITORY git@github.com:Pretty-Good-RISC-V/TileLink.git
    GIT_TAG        "main"
)

FetchContent_MakeAvailable(tilelink)
