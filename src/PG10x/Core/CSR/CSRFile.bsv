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
    // Supervisor Trap Setup
    //
    SSTATUS         = 12'h100,    // Supervisor Status Register (SRW)
    SIE             = 12'h104,    // Supervisor Interrupt Enable Register (SRW)
    STVEC           = 12'h105,    // Supervisor Trap-Handler base address (SRW)
    SCOUNTEREN      = 12'h106,    // Supervisor Counter Enable Register (SRW)

    //
    // Supervisor Configuration
    //
    SENVCFG         = 12'h10A,    // Supervisor environment configuration register (SRW)

    //
    // Supervisor Trap Handling
    //
    SSCRATCH        = 12'h140,    // Scratch register for supervisor trap handlers (SRW)
    SEPC            = 12'h141,    // Supervisor exception program counter (SRW)
    SCAUSE          = 12'h142,    // Supervisor trap cause (SRW)
    STVAL           = 12'h143,    // Supervisor bad address or instruction (SRW)
    SIP             = 12'h144,    // Supervisor interrupt pending (SRW)

    //
    // Supervisor Protection and Translation
    //
    SATP            = 12'h180,    // Supervisor address translation and protection (SRW)

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
    // Machine Memory Protection
    //
    PMPCFG0         = 12'h3A0,    // Physical memory protection configuration (MRW)
    PMPCFG15        = 12'h3AF, 
    PMPADDR0        = 12'h3B0,    // Physical memory protection address register (MRW)
    PMPADDR63       = 12'h3EF,

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

    CYCLE           = 12'hC00,    // Read only mirror of MCYCLE

    //
    // Machine Information Registers
    //
    MVENDORID       = 12'hF11,    // Vendor ID (MRO)
    MARCHID         = 12'hF12,    // Architecture ID (MRO)
    MIMPID          = 12'hF13,    // Implementation ID (MRO)
    MHARTID         = 12'hF14,    // Hardware thread ID (MRO)
    MCONFIGPTR      = 12'hF15     // Pointer to configuration data structure (MRO)
} CSR deriving(Bits, Eq);

typedef enum {
    STATUS          = 8'h00,      // Status
    EDELEG          = 8'h02,      // Exception Delegation
    IDELEG          = 8'h03,      // Interrupt Delegation
    IE              = 8'h04,      // Interrupt Enable
    TVEC            = 8'h05,      // Vector Table
    COUNTEREN       = 8'h06,      // Counter Enable

    SCRATCH         = 8'h40,      // Scratch Register
    EPC             = 8'h41,      // Exception Program Counter
    CAUSE           = 8'h42,      // Exception/Interrupt Cause
    TVAL            = 8'h43,      // Bad address or instruction
    IP              = 8'h44       // Interrupt Pending
} CSRIndexOffset deriving(Bits, Eq);

interface CSRFile;
    // Generic read/write support
    method Maybe#(Word) read(CSRIndex index, Integer portNumber);
    method Maybe#(Word) readWithOffset(CSRIndexOffset offset, Integer portNumber);

    method ActionValue#(Bool) write(CSRIndex index, Word value, Integer portNumber);
    method ActionValue#(Bool) writeWithOffset(CSRIndexOffset offset, Word value, Integer portNumber);

    method Bool machineModeInterruptsEnabled;
    method Action setMachineModeInterruptsEnabled(Bool areEnabled);

    // Special purpose
    method Word64 cycle_counter;
    method Action increment_cycle_counter;
    method Word64 instructions_retired_counter;
    method Action increment_instructions_retired_counter;
endinterface

module mkCSRFile(CSRFile);
    MachineInformation machineInformation <- mkMachineInformationRegisters(0, 0, 0, 0, 0);
    MachineStatus   machineStatus <- mkMachineStatusRegister;
    MachineTraps    machineTraps <- mkMachineTrapRegisters;

    Reg#(Word64)    cycleCounter                <- mkReg(0);
    Reg#(Word64)    timeCounter                 <- mkReg(0);
    Reg#(Word64)    instructionsRetiredCounter  <- mkReg(0);

    Reg#(Word)      mcycle      <- mkReg(0);
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
    Reg#(Word)      mscratch    <- mkReg(0);
    Reg#(Word)      mip         <- mkReg(0);
    Reg#(Word)      mie         <- mkReg(0);

    Reg#(Bit#(2))   currentPrivilegeLevel     <- mkReg(priv_MACHINE);

    function Bool isWARLIgnore(CSRIndex index);
        Bool result = False;

        if ((index >= pack(PMPADDR0) && index <= pack(PMPADDR63)) ||
            (index >= pack(PMPCFG0) && index <= pack(PMPCFG15)) ||
            index == pack(SATP) ||
            index == pack(MIDELEG) ||
            index == pack(MEDELEG)) begin
            result = True;
        end

        return result;
    endfunction

    function CSRIndex getIndex(CSRIndexOffset offset);
        CSRIndex index = 0;
        index[9:8] = currentPrivilegeLevel[1:0];
        index[7:0] = extend(pack(offset));
        return index;
    endfunction

    function Maybe#(Word) readInternal(CSRIndex index, Integer portNumber);
        if (isWARLIgnore(index)) begin
            return tagged Valid 0;
        end else begin
            return case(unpack(index))
                // Machine Information Registers (MRO)
                MVENDORID:  tagged Valid extend(machineInformation.mvendorid);
                MARCHID:    tagged Valid machineInformation.marchid;
                MIMPID:     tagged Valid machineInformation.mimpid;
                MHARTID:    tagged Valid machineInformation.mhartid;
                MISA:       tagged Valid machineTraps.setup.machineISA.read;

                MCAUSE:     tagged Valid mcause[portNumber];
                MTVEC:      tagged Valid mtvec[portNumber];
                MEPC:       tagged Valid mepc[portNumber];
                MTVAL:      tagged Valid 0;

                MSTATUS:    tagged Valid machineStatus.read;
                MCYCLE, CYCLE:     
                    tagged Valid mcycle;
                MSCRATCH:   tagged Valid mscratch;
                MIP:        tagged Valid mip;
                MIE:        tagged Valid mie;
                
                default:    tagged Invalid;
            endcase;
        end
    endfunction

    function ActionValue#(Bool) writeInternal(CSRIndex index, Word value, Integer portNumber);
        actionvalue
        let result = False;
        $display("CSR Write: $%x = $%x", index, value);
        // Access and write to read-only CSR check.
        if (isWARLIgnore(index)) begin
            // Ignore writes to WARL ignore indices
            result = True;
        end else begin
            case(unpack(index))
                MCAUSE: begin
                    mcause[portNumber] <= value;
                    result = True;
                end

                MCYCLE: begin
                    mcycle <= value;
                    result = True;
                end

                MEPC: begin
                    mepc[portNumber] <= value;
                    result = True;
                end

                MISA: begin
                    machineTraps.setup.machineISA.write(value);
                    result = True;
                end

                MSCRATCH: begin
                    mscratch <= value;
                    result = True;
                end

                MSTATUS: begin
                    machineStatus.write(value);
                    result = True;
                end

                MTVAL: begin
                    // IGNORED
                    result = True;
                end

                MTVEC: begin
                    $display("Setting MTVEC to $%0x", value);
                    mtvec[portNumber] <= value;
                    result = True;
                end

                MIE: begin
                    $display("Setting MIE to $%0x", value);
                    mie <= value;
                    result = True;
                end

                MIP: begin
                    $display("Setting MIP to $%0x", value);
                    mip <= value;
                    result = True;
                end
            endcase
        end

        return result;
        endactionvalue
    endfunction

    method Maybe#(Word) read(CSRIndex index, Integer portNumber);
        if (currentPrivilegeLevel < index[9:8]) begin
            return tagged Invalid;
        end else begin
            return readInternal(index, portNumber);
        end
    endmethod

    method Maybe#(Word) readWithOffset(CSRIndexOffset offset, Integer portNumber);
        return readInternal(getIndex(offset), portNumber);
    endmethod

    method ActionValue#(Bool) write(CSRIndex index, Word value, Integer portNumber);
        let result = False;
        if (currentPrivilegeLevel >= index[9:8] && index[11:10] != 'b11) begin
            result <- writeInternal(index, value, portNumber);
        end else begin
            $display("CSR: Attempt to write to $%0x failed due to access check", index);
        end

        return result;
    endmethod

    method ActionValue#(Bool) writeWithOffset(CSRIndexOffset offset, Word value, Integer portNumber);
        let result <- writeInternal(getIndex(offset), value, portNumber);
        return result;
    endmethod

    method Bool machineModeInterruptsEnabled;
        return machineStatus.machineModeInterruptsEnabled;
    endmethod

    method Action setMachineModeInterruptsEnabled(Bool areEnabled);
        machineStatus.setMachineModeInterruptsEnabled(areEnabled);
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
