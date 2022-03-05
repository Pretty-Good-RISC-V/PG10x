#include "ProgramMemory.hpp"
#include <errno.h>
#include <iostream>
#include <assert.h>

int main(int argc, const char *argv[]) {
    int status = EPERM; // Generic failure

    ::setenv("PROGRAM_MEMORY_FILE", "./test_assets/rv32mi-p-csr", 1);
    auto handle = program_memory_open();
    if (handle != 0) {
        address_t addr = 0x80000000;
        assert(program_memory_read_u32(handle, addr) == 0x04c0006f);

        addr += 4;
        assert(program_memory_read_u32(handle, addr) == 0x34202f73);

        addr = 0x8000004c;
        assert(program_memory_read_u32(handle, addr) == 0x00000093);

        addr = 0x800000c8;
        assert(program_memory_read_u32(handle, addr) == 0xf1402573);

        addr = 0x800000c8;
        assert(program_memory_read_u8(handle, addr) == 0x73);

        status = 0;
        program_memory_close(handle);
    }

    return status;
}
