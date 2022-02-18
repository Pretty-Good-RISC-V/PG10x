import PGTypes::*;

import CSRFile::*;
import Exception::*;

import Assert::*;

interface ExceptionController;
    method ActionValue#(ProgramCounter) beginException(RVPrivilegeLevel privilegeLevel, ProgramCounter exceptionProgramCounter, Exception exception);
    method Action endException();
endinterface

module mkExceptionController#(
    CSRFile csrFile
)(ExceptionController);
    Reg#(Maybe#(Exception)) currentException <- mkReg(tagged Invalid);

    method ActionValue#(ProgramCounter) beginException(RVPrivilegeLevel privilegeLevel, ProgramCounter exceptionProgramCounter, Exception exception);
        if (isValid(currentException)) begin
            $display("Exception during handling of exception...halting");
            $fatal();
        end

        let newPrivilegeLevel = PRIVILEGE_LEVEL_MACHINE;

        currentException <= tagged Valid exception;

        let mcause = getMCAUSE(exception);
        csrFile.write0(newPrivilegeLevel, pack(MCAUSE), mcause);
        csrFile.write0(newPrivilegeLevel, pack(MEPC), exceptionProgramCounter);

        Word vectorTableBase = unJust(csrFile.read0(newPrivilegeLevel, pack(MTVEC)));
        let exceptionHandler = vectorTableBase;
        if (vectorTableBase[1:0] == 1) begin
            if(exception matches tagged InterruptCause .interruptCause) begin
                exceptionHandler = vectorTableBase + extend(4 * interruptCause);
            end
        end

        return exceptionHandler;
    endmethod

    method Action endException;
        dynamicAssert(isValid(currentException) == False, "Attempted to call endException when not handling exception");
        currentException <= tagged Invalid;
    endmethod
endmodule
