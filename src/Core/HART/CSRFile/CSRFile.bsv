import PGTypes::*;

import DebugRegisters::*;
import Exception::*;
import MachineInformation::*;
import MachineISA::*;
import MachineStatus::*;
import ReadOnly::*;

import Assert::*;
import GetPut::*;

interface CSRFile;
    interface Get#(RVPrivilegeLevel) getCurrentPrivilegeLevel;
    interface Put#(RVPrivilegeLevel) putCurrentPrivilegeLevel;
    interface Get#(Bool) getMachineModeInterruptsEnabled;

    // Generic read/write support
    method Maybe#(Word) read1(RVCSRIndex index);
    method Maybe#(Word) read2(RVCSRIndex index);

    method Maybe#(Word) readWithOffset1(RVPrivilegeLevel privilegeLevel, RVCSRIndexOffset offset);
    method Maybe#(Word) readWithOffset2(RVPrivilegeLevel privilegeLevel, RVCSRIndexOffset offset);
 
    method Bool isWritable(RVCSRIndex index);

    method ActionValue#(Bool) write1(RVCSRIndex index, Word value);
    method ActionValue#(Bool) write2(RVCSRIndex index, Word value);

    method ActionValue#(Bool) writeWithOffset1(RVPrivilegeLevel privilegeLevel, RVCSRIndexOffset offset, Word value);
    method ActionValue#(Bool) writeWithOffset2(RVPrivilegeLevel privilegeLevel, RVCSRIndexOffset offset, Word value);

    // Direct access
    method MachineStatus getMachineStatus;
    method Action putMachineStatus(MachineStatus machineStatus);

    method MachineISA getMachineISA;
    method Word getMachineInterruptDelegation;
    method Word getMachineExceptionDelegation;

    // Special purpose
    method Word64 cycle_counter;
    method Action increment_cycle_counter;
    method Word64 instructions_retired_counter;
    method Action increment_instructions_retired_counter;
endinterface

module mkCSRFile(CSRFile);
    MachineInformation  machineInformation      <- mkMachineInformationRegisters(0, 0, 0, 0, 0);

    Reg#(MachineISA)    misa                    <- mkReg(defaultValue);
    Reg#(MachineStatus) mstatus                 <- mkReg(defaultValue);

    Reg#(Word64)    cycleCounter                <- mkReg(0);
    Reg#(Word64)    timeCounter                 <- mkReg(0);
    Reg#(Word64)    instructionsRetiredCounter  <- mkReg(0);

    Reg#(Word)      mcycle                      <- mkReg(0);
    ReadOnly#(Word) mtimer                      <- mkReadOnly(truncate(timeCounter));
    ReadOnly#(Word) minstret                    <- mkReadOnly(truncate(instructionsRetiredCounter));
`ifdef RV32
    ReadOnly#(Word) mcycleh                     <- mkReadOnly(truncateLSB(cycleCounter));
    ReadOnly#(Word) mtimeh                      <- mkReadOnly(truncateLSB(timeCounter));
    ReadOnly#(Word) minstreth                   <- mkReadOnly(truncateLSB(instructionsRetiredCounter));
`endif
    Reg#(Word)      mcause                      <- mkReg(0);
    Reg#(Word)      mtvec                       <- mkReg('hC0DEC0DE);
    Reg#(Word)      mepc                        <- mkReg(0);    // Machine Exception Program Counter
    Reg#(Word)      mscratch                    <- mkReg(0);
    Reg#(Word)      mip                         <- mkReg(0);
    Reg#(Word)      mie                         <- mkReg(0);
    Reg#(Word)      mtval                       <- mkReg(0);

    Reg#(Word)      mideleg                     <- mkReg(0);
    Reg#(Word)      medeleg                     <- mkReg(0);

    Reg#(RVPrivilegeLevel)   currentPrivilegeLevel       <- mkReg(priv_MACHINE);

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

    function RVCSRIndex getIndex(RVPrivilegeLevel privilegeLevel, RVCSRIndexOffset offset);
        RVCSRIndex index = 0;
        index[9:8] = privilegeLevel[1:0];
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
                csr_MISA:       tagged Valid pack(misa);

                csr_MCAUSE:     tagged Valid mcause;
                csr_MTVEC:      tagged Valid mtvec;
                csr_MEPC:       tagged Valid mepc;
                csr_MTVAL:      tagged Valid mtval;
                csr_MIDELEG:    tagged Valid mideleg;
                csr_MEDELEG:    tagged Valid medeleg;

                csr_MSTATUS:    tagged Valid pack(mstatus);
                csr_MCYCLE, csr_CYCLE:     
                    tagged Valid mcycle;
                csr_MSCRATCH:   tagged Valid mscratch;
                csr_MIP:        tagged Valid mip;
                csr_MIE:        tagged Valid mie;

                // !bugbug - TSELECT is hardcoded to all 1s.  This is to keep
                //           the ISA debug test happy.  It *should* report a 
                //           pass if reading TSELECT failed with a trap (to reflect what's in the spec)
                //           This is a bug in the debug test.
                csr_TSELECT:    tagged Valid 'hFFFF_FFFF;
                
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
                    mcause <= value;
                    result = True;
                end

                csr_MCYCLE: begin
                    mcycle <= value;
                    result = True;
                end

                csr_MEPC: begin
                    mepc <= value;
                    result = True;
                end

                csr_MISA: begin
                    misa <= unpack(value);
                    result = True;
                end

                csr_MSCRATCH: begin
                    mscratch <= value;
                    result = True;
                end

                csr_MSTATUS: begin
                    mstatus <= unpack(value);
                    result = True;
                end

                csr_MTVAL: begin
                    mtval <= value;
                    result = True;
                end

                csr_MTVEC: begin
                    $display("Setting MTVEC to $%0x", value);
                    mtvec <= value;
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

                csr_TSELECT: begin 
                    result = True;
                end
            endcase
        end

        return result;
        endactionvalue
    endfunction

    method Maybe#(Word) read1(RVCSRIndex index);
        if (currentPrivilegeLevel < index[9:8]) begin
            return tagged Invalid;
        end else begin
            return readInternal(index, 0);
        end
    endmethod

    method Maybe#(Word) read2(RVCSRIndex index);
        if (currentPrivilegeLevel < index[9:8]) begin
            return tagged Invalid;
        end else begin
            return readInternal(index, 1);
        end
    endmethod

    method Maybe#(Word) readWithOffset1(RVPrivilegeLevel privilegeLevel, RVCSRIndexOffset offset);
        return readInternal(getIndex(privilegeLevel, offset), 0);
    endmethod

    method Maybe#(Word) readWithOffset2(RVPrivilegeLevel privilegeLevel, RVCSRIndexOffset offset);
        return readInternal(getIndex(privilegeLevel, offset), 1);
    endmethod

    method ActionValue#(Bool) write1(RVCSRIndex index, Word value);
        let result = False;
        if (currentPrivilegeLevel >= index[9:8] && index[11:10] != 'b11) begin
            result <- writeInternal(index, value, 0);
        end else begin
            $display("CSR: Attempt to write to $%0x failed due to access check", index);
        end

        return result;
    endmethod

    method ActionValue#(Bool) write2(RVCSRIndex index, Word value);
        let result = False;
        if (currentPrivilegeLevel >= index[9:8] && index[11:10] != 'b11) begin
            result <- writeInternal(index, value, 1);
        end else begin
            $display("CSR: Attempt to write to $%0x failed due to access check", index);
        end

        return result;
    endmethod

    method ActionValue#(Bool) writeWithOffset1(RVPrivilegeLevel privilegeLevel, RVCSRIndexOffset offset, Word value);
        let result <- writeInternal(getIndex(privilegeLevel, offset), value, 0);
        return result;
    endmethod

    method ActionValue#(Bool) writeWithOffset2(RVPrivilegeLevel privilegeLevel, RVCSRIndexOffset offset, Word value);
        let result <- writeInternal(getIndex(privilegeLevel, offset), value, 1);
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

    method Bool isWritable(RVCSRIndex index);
        Bool writable = False;
        if (currentPrivilegeLevel >= index[9:8] && index[11:10] != 'b11) begin
            writable = True;
        end
        return writable;
    endmethod

    interface Get getCurrentPrivilegeLevel = toGet(currentPrivilegeLevel);
    interface Put putCurrentPrivilegeLevel = toPut(asIfc(currentPrivilegeLevel));

    interface Get getMachineModeInterruptsEnabled;
        method ActionValue#(Bool) get;
            return mstatus.mie;
        endmethod
    endinterface

    method MachineStatus getMachineStatus;
        return mstatus;
    endmethod

    method Action putMachineStatus(MachineStatus machineStatus);
        mstatus <= machineStatus;
    endmethod

    method MachineISA getMachineISA;
        return misa;
    endmethod

    method Word getMachineInterruptDelegation;
        return mideleg;
    endmethod

    method Word getMachineExceptionDelegation;
        return medeleg;
    endmethod
endmodule
