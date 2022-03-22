#include "ProgramMemory.hpp"

#include <assert.h>
#include <map>
#include <memory>
#include <set>
#include <string>
#include <sstream>

#include <elfio/elfio.hpp>

template< typename T >
std::string to_hex(T i)
{
    std::stringstream stream;
    stream << std::setfill ('0') << std::setw(sizeof(T)*2) << std::hex << (int)i;
    return stream.str();
}

struct Section {
    std::string name;
    address_t address;
    std::vector<uint8_t> data;

    Section(const ELFIO::section *elf_section) {
        name = elf_section->get_name();
        address = elf_section->get_address();

        data.reserve(32768);

        data.resize(elf_section->get_size());
        std::copy(elf_section->get_data(), elf_section->get_data() + elf_section->get_size(), data.begin());
    }

    bool contains(address_t check) const {
        return check >= address && check < (address + data.size());
    }

    void dump(std::ostream &dumpstream) const {
        dumpstream << "Section: " << name << std::endl;
        dumpstream << "Address: $" << std::hex << address << std::endl;

        auto dump_address = address;
        auto i = 0;
        for (auto value : data) {
            if (i % 16 == 0) {
                dumpstream << std::endl << "$" << std::hex << dump_address << ": ";
            }

            dumpstream << std::setfill ('0') << std::setw(2) << to_hex(value) << "  ";
            ++dump_address;
            ++i;
        }

        dumpstream << std::endl << std::endl;
    }
};

struct SectionCompare {
    bool operator ()(const std::shared_ptr<Section> &a, const std::shared_ptr<Section> &b) const {
        assert(a);
        assert(b);
        return a->address < b->address; 
    }
};

struct Context {
    std::set<std::shared_ptr<Section>, SectionCompare> sections;
    std::shared_ptr<Section> find(address_t address) const {
        for (const auto s : sections) {
            if (s->contains(address)) {
                return s;
            }
        }

        return std::shared_ptr<Section>();
    }

    address_t signature_memory_begin = 0;
    address_t signature_memory_end = 0;
};

uint32_t next_handle = 1;
std::map<uint32_t, std::shared_ptr<Context>> contexts;

uint32_t program_memory_open() {
    uint32_t handle = 0;
    std::shared_ptr<Context> context(new Context);

    ELFIO::elfio reader;

    std::string filename;
    // If the filename is empty, pull it from the environment
    const auto environmentVariable = ::getenv("PROGRAM_MEMORY_FILE");
    if (environmentVariable == nullptr) {
        std::cout << "ERROR: no filename specified and no filename available in PROGRAM_MEMORY_FILE environment variable" << std::endl;
    } else {
        filename = std::string(environmentVariable);
    }

    if (filename.empty() || !reader.load(filename)) {
        std::cout << "ERROR: Can't find or process ELF file " << filename << std::endl;
    } else {
        std::shared_ptr<Section> previous_section;

        for (const auto section : reader.sections) {
            // std::cout << "======================================" << std::endl;
            // std::cout << "Loading ELF section: " << section->get_name() << std::endl;
            // std::cout << "               Type: " << section->get_type() << std::endl;
            // std::cout << "            Address: " << std::hex << section->get_address() << std::endl;
            // std::cout << "               Size: " << std::hex << section->get_size() << std::endl;
            // std::cout << "      Address Align: " << std::dec << section->get_addr_align() << std::endl;
            // std::cout << "         Entry Size: " << std::dec << section->get_entry_size() << std::endl;
            // std::cout << "        Name Offset: " << std::hex << section->get_name_string_offset() << std::endl;
            // std::cout << "             Offset: " << std::hex << section->get_offset() << std::endl;

            switch(section->get_type()) {
                case ELFIO::SHT_PROGBITS: {
                    if(previous_section && 
                        section->get_address() >= previous_section->address &&
                        section->get_address() < (previous_section->address + previous_section->data.size() + 8192)) {

                        // std::cout << "Merging section with previous section" << std::endl;

                        const size_t new_size = (section->get_address() + section->get_size()) -
                            previous_section->address;

                        // std::cout << "New section size: " << std::hex << new_size << std::endl;
                        const size_t byte_offset = section->get_address() - previous_section->address;
                        // std::cout << "Copy offset: " << std::hex << byte_offset << std::endl;

                        previous_section->data.resize(new_size);

                        std::copy(section->get_data(), section->get_data() + section->get_size(),
                            &previous_section->data[byte_offset]);
                    } else {
                        std::shared_ptr<Section> new_section(new Section(section));
                        previous_section = new_section;
                        context->sections.insert(new_section);
                    }
                }
                break;

                case ELFIO::SHT_SYMTAB: {
                    ELFIO::symbol_section_accessor ssa(reader, section);

                    ELFIO::Elf64_Addr value;
                    ELFIO::Elf_Xword size;
                    unsigned char bind, type, other;
                    ELFIO::Elf_Half section_index;
                    ssa.get_symbol("begin_signature", value, size, bind, type, section_index, other);
                    context->signature_memory_begin = value;

                    ssa.get_symbol("end_signature", value, size, bind, type, section_index, other);
                    context->signature_memory_end = value;
                }
            }
        }

        if (context->sections.size() == 0) {
            std::cout << "ERROR: No loadable sections found in ELF file." << std::endl;
        } else {
            handle = ++next_handle;
        }
    }

    if (handle != 0 && context) {
        contexts[handle] = std::move(context);
    }

    return handle;
}

void program_memory_close(uint32_t handle) {
    contexts.erase(handle);
}

bool program_memory_is_valid_address(uint32_t handle, address_t address) {
    bool is_valid = false;
    const auto &i = contexts.find(handle);
    if (i != contexts.end()) {
        const auto context = (*i).second;
        for (const auto &section : context->sections) {
            if (section->contains(address)) {
                is_valid = true;
                break;
            }
        }
    }

    return is_valid;
}

template <typename T>
struct AlignmentTraits {
    static bool isAligned(address_t address);
    static T defaultValue();
    static std::string name();
};

template<>
bool AlignmentTraits<uint8_t>::isAligned(address_t address) {
    return true;
}

template<>
std::string AlignmentTraits<uint8_t>::name() {
    return std::string("uint8_t");
}

template<>
uint8_t AlignmentTraits<uint8_t>::defaultValue() {
    return 0xAA;
}

template<>
bool AlignmentTraits<uint16_t>::isAligned(address_t address) {
    return (address & 1) == 0;
}

template<>
std::string AlignmentTraits<uint16_t>::name() {
    return std::string("uint16_t");
}

template<>
uint16_t AlignmentTraits<uint16_t>::defaultValue() {
    return 0xAACC;
}

template<>
bool AlignmentTraits<uint32_t>::isAligned(address_t address) {
    return (address & 3) == 0;
}

template<>
std::string AlignmentTraits<uint32_t>::name() {
    return std::string("uint32_t");
}

template<>
uint32_t AlignmentTraits<uint32_t>::defaultValue() {
    return 0xABCDABCD;
}

template<>
bool AlignmentTraits<uint64_t>::isAligned(address_t address) {
    return (address & 7) == 0;
}

template<>
std::string AlignmentTraits<uint64_t>::name() {
    return std::string("uint64_t");
}

template<>
uint64_t AlignmentTraits<uint64_t>::defaultValue() {
    return 0xABCDABCDABCDABCD;
}

template<typename T>
T program_memory_read(std::shared_ptr<Context> context, address_t address) {
    T result = AlignmentTraits<T>::defaultValue();
    const auto &s = context->find(address);
    if (s) {
        const auto sectionOffset = address - s->address;
        result = *(const T *)&s->data[sectionOffset];
    } else {
        std::cout << "Failed loading value...address not found in section" << std::endl;
    }

    return result;
}

template<typename T>
T program_memory_read(context_handle handle, address_t address) {
    T result = AlignmentTraits<T>::defaultValue();
    const auto &i = contexts.find(handle);
    if (i != contexts.end()) {
        result = program_memory_read<T>((*i).second, address);
    } else {
        std::cerr << "Error: Context not found" << std::endl;
    }

    return result;
}

template<typename T>
void program_memory_write(context_handle handle, address_t address, T value) {
    const auto &i = contexts.find(handle);
    if (i != contexts.end()) {
        auto s = (*i).second->find(address);
        if (s) {
            const auto sectionOffset = address - s->address;
            std::cout << "Section base: " << std::hex << s->address << ", Size: $" << s->data.size() << " - Storing $" << std::hex << value << " to: $" << address << " - Section offset: " << sectionOffset << std::endl;
            uint8_t *data = s->data.data();
            uint8_t *area = &data[sectionOffset];
            *(T *)area = value;
            std::cout << "Written: " << std::hex << *(T *)area << std::endl;
        } else {
            std::cout << "Failed storing value...address not found in section" << std::endl;
        }
    } else {
        std::cerr << "Error: Context not found" << std::endl;
    }
}

uint8_t program_memory_read_u8(context_handle handle, address_t address) {
    return program_memory_read<uint8_t>(handle, address);
}

uint16_t program_memory_read_u16(context_handle handle, address_t address) {
    return program_memory_read<uint16_t>(handle, address);
}

uint32_t program_memory_read_u32(context_handle handle, address_t address) {
    return program_memory_read<uint32_t>(handle, address);
}

uint64_t program_memory_read_u64(context_handle handle, address_t address) {
    return program_memory_read<uint64_t>(handle, address);
}

void program_memory_write_u8(context_handle handle, address_t address, uint8_t value) {
    program_memory_write(handle, address, value);
}

void program_memory_write_u16(context_handle handle, address_t address, uint16_t value) {
    program_memory_write(handle, address, value);
}

void program_memory_write_u32(context_handle handle, address_t address, uint32_t value) {
    program_memory_write(handle, address, value);
}

void program_memory_write_u64(context_handle handle, address_t address, uint64_t value) {
    program_memory_write(handle, address, value);
}

void program_memory_dump(context_handle handle) {
    const auto &i = contexts.find(handle);
    if (i != contexts.end()) {
        const auto context = (*i).second;

        for (const auto section : context->sections) {
            section->dump(std::cout);
        }
    }
}

void program_memory_dump_signature_area(context_handle handle) {
    const auto filename = ::getenv("SIGNATURE_FILENAME");
    if (!filename) {
        std::cerr << "Warning: no signature filename specified in SIGNATURE_FILENAME environment variable" << std::endl;
    } else {
        std::ofstream signatureFile(std::string(filename), std::ios_base::trunc);
        const auto &i = contexts.find(handle);
        if (i != contexts.end()) {
            const auto context = (*i).second;

            assert((context->signature_memory_begin & 3) == 0);
            assert((context->signature_memory_end & 3) == 0);

            for (auto address = context->signature_memory_begin; address < context->signature_memory_end; address += 4) {
                const auto value = program_memory_read<uint32_t>(context, address);
                std::cout << "Dumping $" << std::hex << address << " = " << value << std::endl;
                signatureFile << std::hex << std::setfill ('0') << std::setw(8) << value << std::endl;
            }
        }
    }
}
