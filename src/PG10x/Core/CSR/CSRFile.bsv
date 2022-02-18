import PGTypes::*;

import Exception::*;
import MachineInformation::*;
import MachineStatus::*;
import MachineTraps::*;

import Assert::*;

function Reg#(t) readOnlyReg(t r);
    return (interface Reg;
            method t _read = r;
            method Action _write(t x) = noAction;
        endinterface);
endfunction

function Reg#(t) readOnlyRegWarn(t r, String msg);
    return (interface Reg;
            method t _read = r;
            method Action _write(t x);
                $fdisplay(stderr, "[WARNING] readOnlyReg: %s", msg);
            endmethod
        endinterface);
endfunction

function Reg#(t) readOnlyRegError(t r, String msg);
    return (interface Reg;
            method t _read = r;
            method Action _write(t x);
                $fdisplay(stderr, "[ERROR] readOnlyReg: %s", msg);
                $finish(1);
            endmethod
        endinterface);
endfunction

module mkReadOnlyReg#(t x)(Reg#(t));
    return readOnlyReg(x);
endmodule

module mkReadOnlyRegWarn#(t x, String msg)(Reg#(t));
    return readOnlyRegWarn(x, msg);
endmodule

module mkReadOnlyRegError#(t x, String msg)(Reg#(t));
    return readOnlyRegError(x, msg);
endmodule

typedef enum {
    //
    // Machine Trap Setup
    //
    MSTATUS         = 12'h300,    // Machine Status Register (MRW)
    MISA            = 12'h301,    // Machine ISA and Extensions Register (MRW)
    MEDELEG         = 12'h302,    // Machine Exception Delegation Register (MRW)
    MIDELEG         = 12'h303,    // Machine Interrupt Delegation Register (MRW)
    MIE             = 12'h304,    // Machine Interrupt Enable Register (MRW)
    MTVEC           = 12'h305,    // Machine Trap-Handler base address (MRW)
    MCOUNTEREN      = 12'h306,    // Machine Counter Enable Register (MRW)
`ifdef RV32
    MSTATUSH        = 12'h310,    // Additional machine status register, RV32 only (MRW)
`endif

    //
    // Macine Trap Handling
    //
    MSCRATCH        = 12'h340,    // Scratch register for machine trap handlers (MRW)
    MEPC            = 12'h341,    // Machine exception program counter (MRW)
    MCAUSE          = 12'h342,    // Machine trap cause (MRW)
    MTVAL           = 12'h343,    // Machine bad address or instruction (MRW)
    MIP             = 12'h344,    // Machine interrupt pending (MRW)
    MTINST          = 12'h34A,    // Machine trap instruction (transformed) (MRW)
    MTVAL2          = 12'h34B,    // Machine bad guest physical address (MRW)

    //
    // Machine Counters/Timers
    //
    MCYCLE          = 12'hB00,    // Cycle counter for RDCYCLE instruction (MRW)
    MINSTRET        = 12'hB02,    // Machine instructions-retired counter (MRW)
    MHPMCOUNTER3    = 12'hB03,    // Machine performance-monitoring counter (MRW)
    MHPMCOUNTER4    = 12'hB04,    // Machine performance-monitoring counter (MRW)
    MHPMCOUNTER5    = 12'hB05,    // Machine performance-monitoring counter (MRW)
    MHPMCOUNTER6    = 12'hB06,    // Machine performance-monitoring counter (MRW)
    MHPMCOUNTER7    = 12'hB07,    // Machine performance-monitoring counter (MRW)
    MHPMCOUNTER8    = 12'hB08,    // Machine performance-monitoring counter (MRW)
    MHPMCOUNTER9    = 12'hB09,    // Machine performance-monitoring counter (MRW)
`ifdef RV32
    MCYCLEH         = 12'hB80,    // Upper 32 bits of mcycle, RV32I only (MRW)
    MINSTRETH       = 12'hB82,    // Upper 32 bits of minstret, RV32I only (MRW)    
    MHPMCOUNTER3H   = 12'hB83,    // Machine performance-monitoring counter (upper 32 bits) (MRW)
    MHPMCOUNTER4H   = 12'hB84,    // Machine performance-monitoring counter (upper 32 bits) (MRW)
    MHPMCOUNTER5H   = 12'hB85,    // Machine performance-monitoring counter (upper 32 bits) (MRW)
    MHPMCOUNTER6H   = 12'hB86,    // Machine performance-monitoring counter (upper 32 bits) (MRW)
    MHPMCOUNTER7H   = 12'hB87,    // Machine performance-monitoring counter (upper 32 bits) (MRW)
    MHPMCOUNTER8H   = 12'hB88,    // Machine performance-monitoring counter (upper 32 bits) (MRW)
    MHPMCOUNTER9H   = 12'hB89,    // Machine performance-monitoring counter (upper 32 bits) (MRW)
`endif

    //
    // Machine Information Registers
    //
    MVENDORID       = 12'hF11,    // Vendor ID (MRO)
    MARCHID         = 12'hF12,    // Architecture ID (MRO)
    MIMPID          = 12'hF13,    // Implementation ID (MRO)
    MHARTID         = 12'hF14,    // Hardware thread ID (MRO)
    MCONFIGPTR      = 12'hF15     // Pointer to configuration data structure (MRO)
} CSR deriving(Bits, Eq);

interface CSRFile;
    // Generic read/write support
    method Maybe#(Word) read0(RVPrivilegeLevel curPriv, CSRIndex index);
    method Maybe#(Word) read1(RVPrivilegeLevel curPriv, CSRIndex index);

    method ActionValue#(Bool) write0(RVPrivilegeLevel curPriv, CSRIndex index, Word value);
    method ActionValue#(Bool) write1(RVPrivilegeLevel curPriv, CSRIndex index, Word value);

    // Special purpose
    method Word64 cycle_counter;
    method Action increment_cycle_counter;
    method Word64 instructions_retired_counter;
    method Action increment_instructions_retired_counter;
endinterface

module mkCSRFile(CSRFile);

    MachineInformation machineInformation <- mkMachineInformationRegisters(0, 0, 0, 0, 0);
    MachineStatus machineStatus <- mkMachineStatusRegister();
    MachineTraps machineTraps <- mkMachineTrapRegisters();

    Reg#(Word64)    cycleCounter                <- mkReg(0);
    Reg#(Word64)    timeCounter                 <- mkReg(0);
    Reg#(Word64)    instructionsRetiredCounter  <- mkReg(0);

    Reg#(Word)      mcycle      = readOnlyReg(truncate(cycleCounter));
    Reg#(Word)      mtimer      = readOnlyReg(truncate(timeCounter));
    Reg#(Word)      minstret    = readOnlyReg(truncate(instructionsRetiredCounter));
`ifdef RV32
    Reg#(Word)      mcycleh     = readOnlyReg(truncateLSB(cycleCounter));
    Reg#(Word)      mtimeh      = readOnlyReg(truncateLSB(timeCounter));
    Reg#(Word)      minstreth   = readOnlyReg(truncateLSB(instructionsRetiredCounter));
`endif
    Reg#(Word)      mcause[2]   <- mkCReg(2, 0);
    Reg#(Word)      mtvec[2]    <- mkCReg(2, 'hC0DEC0DE);
    Reg#(Word)      mepc[2]     <- mkCReg(2, 0);    // Machine Exception Program Counter

    function Maybe#(Word) read(RVPrivilegeLevel curPriv, CSRIndex index, Integer portNumber);
        // Access check
        if (pack(curPriv) < index[9:8]) begin
            return tagged Invalid;
        end else begin
            return case(unpack(index))
                // Machine Information Registers (MRO)
                MVENDORID:  tagged Valid extend(machineInformation.mvendorid);
                MARCHID:    tagged Valid machineInformation.marchid;
                MIMPID:     tagged Valid machineInformation.mimpid;
                MHARTID:    tagged Valid machineInformation.mhartid;

                MCAUSE:     tagged Valid mcause[portNumber];
                MTVEC:      tagged Valid mtvec[portNumber];
                MEPC:       tagged Valid mepc[portNumber];
                default:    tagged Invalid;
            endcase;
        end
    endfunction

    function ActionValue#(Bool) write(RVPrivilegeLevel curPriv, CSRIndex index, Word value, Integer portNumber);
        actionvalue
        let result = False;
        // Access and write to read-only CSR check.
        if (pack(curPriv) >= index[9:8] && index[11:10] != 'b11) begin
            case(index)
                pack(MCAUSE): begin
                    mcause[portNumber] <= value;
                    result = True;
                end

                pack(MTVEC): begin
                    mtvec[portNumber] <= value;
                    result = True;
                end

                pack(MEPC): begin
                    mepc[portNumber] <= value;
                    result = True;
                end
            endcase
        end

        return result;
        endactionvalue
    endfunction

    method Maybe#(Word) read0(RVPrivilegeLevel curPriv, CSRIndex index);
        return read(curPriv, index, 0);
    endmethod

    method Maybe#(Word) read1(RVPrivilegeLevel curPriv, CSRIndex index);
        return read(curPriv, index, 1);
    endmethod

    method ActionValue#(Bool) write0(RVPrivilegeLevel curPriv, CSRIndex index, Word value);
        let result <- write(curPriv, index, value, 0);
        return result;
    endmethod

    method ActionValue#(Bool) write1(RVPrivilegeLevel curPriv, CSRIndex index, Word value);
        let result <- write(curPriv, index, value, 1);
        return result;
    endmethod

    method Word64 cycle_counter;
        return cycleCounter;
    endmethod

    method Action increment_cycle_counter;
        cycleCounter <= cycleCounter + 1;
    endmethod

    method Word64 instructions_retired_counter;
        return instructionsRetiredCounter;
    endmethod
    
    method Action increment_instructions_retired_counter;
        instructionsRetiredCounter <= instructionsRetiredCounter + 1;
    endmethod
endmodule
