#pragma once

#include <stdint.h>

#include "PGTypes.hpp"

typedef uint32_t context_handle;

extern "C" {
    context_handle program_memory_open();
    void program_memory_close(context_handle handle);
    bool program_memory_is_valid_address(context_handle handle, address_t address);

    uint8_t program_memory_read_u8(context_handle handle, address_t address);
    uint16_t program_memory_read_u16(context_handle handle, address_t address);
    uint32_t program_memory_read_u32(context_handle handle, address_t address);
    uint64_t program_memory_read_u64(context_handle handle, address_t address);

    void program_memory_write_u8(context_handle handle, address_t address, uint8_t value);
    void program_memory_write_u16(context_handle handle, address_t address, uint16_t value);
    void program_memory_write_u32(context_handle handle, address_t address, uint32_t value);
    void program_memory_write_u64(context_handle handle, address_t address, uint64_t value);

    void program_memory_dump(context_handle handle);
    void program_memory_dump_signature_area(context_handle handle);
}
