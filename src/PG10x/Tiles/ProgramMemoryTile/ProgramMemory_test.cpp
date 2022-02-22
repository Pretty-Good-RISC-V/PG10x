#include "ProgramMemory.hpp"
#include <errno.h>
#include <iostream>

int main(int argc, const char *argv[]) {
    int status = EPERM; // Generic failure

    if (argc != 2) {
        std::cout << "Usage: " << argv[0] << " <ELF file>" << std::endl;
    } else {
        std::string filename(argv[1]);
        auto handle = program_memory_open(filename.c_str());
        if (handle != 0) {
            

            status = 0;
            program_memory_close(handle);
        }
    }

    return status;
}
