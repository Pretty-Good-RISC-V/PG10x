import PGTypes::*;

import Exception::*;
import MachineInformation::*;
import MachineStatus::*;
import MachineTraps::*;
import RegUtil::*;

import Assert::*;

interface CSRFile;
    // Generic read/write support
    method Maybe#(Word) read(RVCSRIndex index, Integer portNumber);
    method Maybe#(Word) readWithOffset(RVCSRIndexOffset offset, Integer portNumber);

    method ActionValue#(Bool) write(RVCSRIndex index, Word value, Integer portNumber);
    method ActionValue#(Bool) writeWithOffset(RVCSRIndexOffset offset, Word value, Integer portNumber);

    method Bool machineModeInterruptsEnabled;

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

    function Bool isWARLIgnore(RVCSRIndex index);
        Bool result = False;

        if ((index >= csr_PMPADDR0 && index <= csr_PMPADDR63) ||
            (index >= csr_PMPCFG0 && index <= csr_PMPCFG15) ||
            index == csr_SATP ||
            index == csr_MIDELEG ||
            index == csr_MEDELEG) begin
            result = True;
        end

        return result;
    endfunction

    function RVCSRIndex getIndex(RVCSRIndexOffset offset);
        RVCSRIndex index = 0;
        index[9:8] = currentPrivilegeLevel[1:0];
        index[7:0] = offset;
        return index;
    endfunction

    function Maybe#(Word) readInternal(RVCSRIndex index, Integer portNumber);
        if (isWARLIgnore(index)) begin
            return tagged Valid 0;
        end else begin
            return case(index)
                // Machine Information Registers (MRO)
                csr_MVENDORID:  tagged Valid extend(machineInformation.mvendorid);
                csr_MARCHID:    tagged Valid machineInformation.marchid;
                csr_MIMPID:     tagged Valid machineInformation.mimpid;
                csr_MHARTID:    tagged Valid machineInformation.mhartid;
                csr_MISA:       tagged Valid machineTraps.setup.machineISA.read;

                csr_MCAUSE:     tagged Valid mcause[portNumber];
                csr_MTVEC:      tagged Valid mtvec[portNumber];
                csr_MEPC:       tagged Valid mepc[portNumber];
                csr_MTVAL:      tagged Valid 0;

                csr_MSTATUS:    tagged Valid machineStatus.read;
                csr_MCYCLE, csr_CYCLE:     
                    tagged Valid mcycle;
                csr_MSCRATCH:   tagged Valid mscratch;
                csr_MIP:        tagged Valid mip;
                csr_MIE:        tagged Valid mie;
                
                default:    tagged Invalid;
            endcase;
        end
    endfunction

    function ActionValue#(Bool) writeInternal(RVCSRIndex index, Word value, Integer portNumber);
        actionvalue
        let result = False;
        $display("CSR Write: $%x = $%x", index, value);
        // Access and write to read-only CSR check.
        if (isWARLIgnore(index)) begin
            // Ignore writes to WARL ignore indices
            result = True;
        end else begin
            case(index)
                csr_MCAUSE: begin
                    mcause[portNumber] <= value;
                    result = True;
                end

                csr_MCYCLE: begin
                    mcycle <= value;
                    result = True;
                end

                csr_MEPC: begin
                    mepc[portNumber] <= value;
                    result = True;
                end

                csr_MISA: begin
                    machineTraps.setup.machineISA.write(value);
                    result = True;
                end

                csr_MSCRATCH: begin
                    mscratch <= value;
                    result = True;
                end

                csr_MSTATUS: begin
                    machineStatus.write(value);
                    result = True;
                end

                csr_MTVAL: begin
                    // IGNORED
                    result = True;
                end

                csr_MTVEC: begin
                    $display("Setting MTVEC to $%0x", value);
                    mtvec[portNumber] <= value;
                    result = True;
                end

                csr_MIE: begin
                    $display("Setting MIE to $%0x", value);
                    mie <= value;
                    result = True;
                end

                csr_MIP: begin
                    $display("Setting MIP to $%0x", value);
                    mip <= value;
                    result = True;
                end
            endcase
        end

        return result;
        endactionvalue
    endfunction

    method Maybe#(Word) read(RVCSRIndex index, Integer portNumber);
        if (currentPrivilegeLevel < index[9:8]) begin
            return tagged Invalid;
        end else begin
            return readInternal(index, portNumber);
        end
    endmethod

    method Maybe#(Word) readWithOffset(RVCSRIndexOffset offset, Integer portNumber);
        return readInternal(getIndex(offset), portNumber);
    endmethod

    method ActionValue#(Bool) write(RVCSRIndex index, Word value, Integer portNumber);
        let result = False;
        if (currentPrivilegeLevel >= index[9:8] && index[11:10] != 'b11) begin
            result <- writeInternal(index, value, portNumber);
        end else begin
            $display("CSR: Attempt to write to $%0x failed due to access check", index);
        end

        return result;
    endmethod

    method ActionValue#(Bool) writeWithOffset(RVCSRIndexOffset offset, Word value, Integer portNumber);
        let result <- writeInternal(getIndex(offset), value, portNumber);
        return result;
    endmethod

    method Bool machineModeInterruptsEnabled;
        return machineStatus.machineModeInterruptsEnabled;
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
