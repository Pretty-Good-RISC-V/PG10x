include(FetchContent)

FetchContent_Declare(
    spike_disasm
    GIT_REPOSITORY git@github.com:Pretty-Good-RISC-V/Spike-DISASM.git
    GIT_TAG        "main"
)

FetchContent_MakeAvailable(spike_disasm)
