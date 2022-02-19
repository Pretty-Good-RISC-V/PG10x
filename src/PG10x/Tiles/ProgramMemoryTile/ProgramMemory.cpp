#include "ProgramMemory.hpp"

#include <map>
#include <memory>
#include <elfio/elfio.hpp>

struct Section {
    std::string name;
    uint64_t address;
    size_t size;
    std::vector<uint8_t> data;
};

struct Context {
    std::vector<Section> sections;
};

uint32_t next_handle = 1;
std::map<uint32_t, std::unique_ptr<Context>> contexts;

uint32_t load(const char *filename) {
    uint32_t handle = 0;
    std::unique_ptr<Context> context(new Context);

    ELFIO::elfio reader;

    if (!reader.load(filename)) {
        std::cout << "Can't find or process ELF file " << filename << std::endl;
    }
    else {
        for (const auto section : reader.sections) {
            std::cout << "Loading ELF section: " << section->get_name() << std::endl;
            std::cout << "               Type: " << section->get_type() << std::endl;
            std::cout << "            Address: " << std::hex << section->get_address() << std::endl;
            std::cout << "               Size: " << std::hex << section->get_size() << std::endl;
            std::cout << "      Address Align: " << std::dec << section->get_addr_align() << std::endl;
            std::cout << "         Entry Size: " << std::dec << section->get_entry_size() << std::endl;
            std::cout << "        Name Offset: " << std::hex << section->get_name_string_offset() << std::endl;
            std::cout << "             Offset: " << std::hex << section->get_offset() << std::endl;
        }
    }

    if (handle != 0 && context) {
        contexts[handle] = std::move(context);
    }

    return handle;
}
