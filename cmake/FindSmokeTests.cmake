include(ExternalProject)

message("Ensuring SmokeTests is available")
ExternalProject_Add(
    smoketests
    GIT_REPOSITORY "https://github.com/Pretty-Good-RISC-V/SmokeTests.git"
    GIT_TAG "main"
    INSTALL_COMMAND ""
)

message("Ensuring SmokeTests is available...complete")

ExternalProject_Get_Property(smoketests SOURCE_DIR)
set(SMOKETESTS_SOURCE_DIR "${SOURCE_DIR}" CACHE STRING "")

ExternalProject_Get_Property(smoketests BINARY_DIR)
set(SMOKETESTS_BINARY_DIR "${BINARY_DIR}" CACHE STRING "")
