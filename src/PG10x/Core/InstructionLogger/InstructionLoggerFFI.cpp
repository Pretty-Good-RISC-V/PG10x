#include <iostream>
#include <fstream>
#include <iomanip>
#include <disasm.h>
#include "InstructionLoggerFFI.hpp"

disassembler_t disassembler(XLEN);
std::ofstream log;

void logInstructionFFI(address_t pc, uint32_t rawInstruction) {
    if (!log.is_open()) {
        const char *logFilename = ::getenv("INSTRUCTION_LOG_FILENAME");
        if (logFilename) {
            log.open(logFilename, std::ios_base::trunc | std::ios_base::out);
            if (!log.is_open()) {
                std::cout << "ERROR: Failed to open log: " << std::string(logFilename) << std::endl;
            }
        }
    }

    if (log.is_open()) {
        insn_t instruction(rawInstruction);

        const auto disassembled = disassembler.disassemble(instruction);

        std::string id("0");
        const size_t max_xlen = XLEN;

        // This output is formatted to match what's output via Spike.
        log << "core " << std::dec << std::setfill(' ') << std::setw(3) << id
            << std::hex << ": 0x" << std::setfill('0') << std::setw(max_xlen/4)
            << zext(pc, max_xlen) << " (0x" << std::setw(8) << rawInstruction << ") "
            << disassembler.disassemble(instruction) << std::endl;        
    }
}
