include(FetchContent)

FetchContent_Declare(
    tilelink
    GIT_REPOSITORY git@github.com:Pretty-Good-RISC-V/TileLink.git
    GIT_TAG        "main"
)

message("Ensuring TileLink is available")
FetchContent_MakeAvailable(tilelink)
message("Ensuring TileLink is available...complete")
