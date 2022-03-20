#pragma once

#include <stdint.h>

typedef uint32_t context_handle;

#ifdef RV32
typedef uint32_t address_t;
#elif RV64
typedef uint64_t address_t;
#endif

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

    address_t program_memory_signature_address_begin(context_handle handle);
    address_t program_memory_signature_address_end(context_handle handle);
}
