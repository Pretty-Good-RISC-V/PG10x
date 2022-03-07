//
// ProgramCounterRedirect
//
// This module is used by various stages to communicate changes to
// the program counter.
//
import PGTypes::*;

export mkProgramCounterRedirect, ProgramCounterRedirect(..);

interface ProgramCounterRedirect;
    method Action branch(ProgramCounter branchTarget);
    method Action exception(ProgramCounter exceptionTarget);
    method ActionValue#(Maybe#(ProgramCounter)) getRedirectedProgramCounter;
endinterface

module mkProgramCounterRedirect(ProgramCounterRedirect);
    Reg#(Maybe#(ProgramCounter)) redirectDueToBranch[2] <- mkCReg(2, tagged Invalid);
    Reg#(Maybe#(ProgramCounter)) redirectDueToException[2] <- mkCReg(2, tagged Invalid);

    method Action branch(ProgramCounter branchTarget);
        redirectDueToBranch[0] <= tagged Valid branchTarget;
    endmethod

    method Action exception(ProgramCounter exceptionTarget);
        redirectDueToException[0] <= tagged Valid exceptionTarget;
    endmethod

    method ActionValue#(Maybe#(ProgramCounter)) getRedirectedProgramCounter;
        let redirect = redirectDueToException[1];
        if (!isValid(redirect)) begin
            redirect = redirectDueToBranch[1];
        end

        if (isValid(redirect)) begin
            redirectDueToBranch[1] <= tagged Invalid;
            redirectDueToException[1] <= tagged Invalid;
        end

        return redirect;
    endmethod
endmodule
