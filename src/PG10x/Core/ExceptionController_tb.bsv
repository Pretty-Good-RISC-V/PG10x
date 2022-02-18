import PGTypes::*;

import CSRFile::*;
import Exception::*;
import ExceptionController::*;

import Assert::*;

typedef enum {
    INIT,
    VERIFY_INIT,
    TEST,
    VERIFY_TEST,
    COMPLETE
} State deriving(Bits, Eq, FShow);

(* synthesize *)
module mkExceptionController_tb(Empty);
    Reg#(State) state <- mkReg(INIT);

    CSRFile csrFile <- mkCSRFile();
    ExceptionController exceptionController <- mkExceptionController(csrFile);

    Word actualExceptionVector = 'h8000;
    ProgramCounter exceptionProgramCounter = 'h4000;
    RVExceptionCause exceptionCause = extend(pack(ILLEGAL_INSTRUCTION));

    rule init(state == INIT);
        let succeeded <- csrFile.write0(PRIVILEGE_LEVEL_USER, pack(MTVEC), actualExceptionVector);
        dynamicAssert(succeeded == False, "Attempt to write MTVEC in user mode should fail.");

        succeeded <- csrFile.write0(PRIVILEGE_LEVEL_MACHINE, pack(MTVEC), actualExceptionVector);
        dynamicAssert(succeeded == True, "Attempt to write MTVEC in machine mode should succeed.");
        state <= VERIFY_INIT;
    endrule

    rule verifyInit(state == VERIFY_INIT);
        let result = csrFile.read0(PRIVILEGE_LEVEL_MACHINE, pack(MTVEC));
        dynamicAssert(isValid(result), "Reading MTVEC in machine mode should succeed.");
        dynamicAssert(unJust(result) == actualExceptionVector, "Reading MTVEC should contain value written");

        state <= TEST;
    endrule

    rule beginException(state == TEST);
        Exception exception = tagged ExceptionCause exceptionCause;
        let receivedExceptionVector <- exceptionController.beginException(PRIVILEGE_LEVEL_USER, exceptionProgramCounter, exception);
        dynamicAssert(receivedExceptionVector == actualExceptionVector, "Exception Vector isn't correct.");

        state <= VERIFY_TEST;
    endrule

    rule endException(state == VERIFY_TEST);
        let mtvec = csrFile.read0(PRIVILEGE_LEVEL_MACHINE, pack(MTVEC));
        dynamicAssert(isValid(mtvec), "Reading MTVEC in machine mode should succeed.");
        dynamicAssert(unJust(mtvec) == actualExceptionVector, "Reading MTVEC should contain value written");

        let mecpc = csrFile.read0(PRIVILEGE_LEVEL_MACHINE, pack(MEPC));
        dynamicAssert(isValid(mecpc), "Reading MEPC in machine mode should succeed.");
        dynamicAssert(unJust(mecpc) == exceptionProgramCounter, "Reading MEPC should contain value written");

        let mcause = csrFile.read0(PRIVILEGE_LEVEL_MACHINE, pack(MCAUSE));
        dynamicAssert(isValid(mcause), "Reading MCAUSE in machine mode should succeed.");

        Exception exceptionActual = tagged ExceptionCause exceptionCause;
        let mcauseActual = getMCAUSE(exceptionActual);
        dynamicAssert(unJust(mcause) == mcauseActual, "Reading MCAUSE should contain value written");

        state <= COMPLETE;
    endrule

    rule complete(state == COMPLETE);
        $display("    PASS");
        $finish();
    endrule
endmodule
