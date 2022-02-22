#pragma once

#include <stdint.h>

typedef uint32_t context_handle;

extern "C" {
    context_handle program_memory_open();
    void program_memory_close(context_handle handle);

    uint32_t program_memory_read(context_handle handle, uint32_t address);
    void program_memory_write(context_handle handle, uint32_t address, uint32_t value, uint32_t write_mask);

    bool program_memory_is_valid_address(context_handle handle, uint32_t address);
}
