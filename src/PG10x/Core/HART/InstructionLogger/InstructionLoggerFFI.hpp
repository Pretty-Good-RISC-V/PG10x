#pragma once

#include <stdint.h>

#ifdef RV32
typedef uint32_t address_t;
#define XLEN 32
#elif RV64
typedef uint64_t address_t;
#define XLEN 64
#endif

extern "C" {
    void logInstructionFFI(address_t pc, uint32_t instruction);
}
