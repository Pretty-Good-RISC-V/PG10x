#pragma once

#include "PGTypes.hpp"

extern "C" {
    void logInstructionFFI(address_t pc, uint32_t instruction);
}
