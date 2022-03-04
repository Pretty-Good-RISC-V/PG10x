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
    SOFTWARE_INTERRUPT_TEST,
    SOFTWARE_INTERRUPT_VERIFY,
    COMPLETE
} State deriving(Bits, Eq, FShow);

(* synthesize *)
module mkExceptionController_tb(Empty);
    Reg#(State) state <- mkReg(INIT);
    Reg#(Word) counter <- mkReg(0);

    ExceptionController exceptionController <- mkExceptionController;

    Word actualExceptionVector = 'h8000;
    ProgramCounter exceptionProgramCounter = 'h4000;
    RVExceptionCause exceptionCause = exception_ILLEGAL_INSTRUCTION;

    rule init(state == INIT);
        let succeeded <- exceptionController.csrFile.writeWithOffset(TVEC, actualExceptionVector, 0);
        dynamicAssert(succeeded == True, "Attempt to write MTVEC in machine mode should succeed.");
        state <= VERIFY_INIT;
    endrule

    rule verifyInit(state == VERIFY_INIT);
        let result = exceptionController.csrFile.readWithOffset(TVEC, 1);
        dynamicAssert(isValid(result), "Reading MTVEC in machine mode should succeed.");
        dynamicAssert(unJust(result) == actualExceptionVector, "Reading MTVEC should contain value written");

        state <= TEST;
    endrule

    rule beginException(state == TEST);
        Exception exception = tagged ExceptionCause exceptionCause;
        let receivedExceptionVector <- exceptionController.beginException(exceptionProgramCounter, exception);
        dynamicAssert(receivedExceptionVector == actualExceptionVector, "Exception Vector isn't correct.");

        state <= VERIFY_TEST;
    endrule

    rule endException(state == VERIFY_TEST);
        let mtvec = exceptionController.csrFile.readWithOffset(TVEC, 0);
        dynamicAssert(isValid(mtvec), "Reading MTVEC in machine mode should succeed.");
        dynamicAssert(unJust(mtvec) == actualExceptionVector, "Reading MTVEC should contain value written");

        let mecpc = exceptionController.csrFile.readWithOffset(EPC, 0);
        dynamicAssert(isValid(mecpc), "Reading MEPC in machine mode should succeed.");
        dynamicAssert(unJust(mecpc) == exceptionProgramCounter, "Reading MEPC should contain value written");

        let mcause = exceptionController.csrFile.readWithOffset(CAUSE, 0);
        dynamicAssert(isValid(mcause), "Reading MCAUSE in machine mode should succeed.");

        Exception exceptionActual = tagged ExceptionCause exceptionCause;
        let mcauseActual = getCause(exceptionActual);
        dynamicAssert(unJust(mcause) == mcauseActual, "Reading MCAUSE should contain value written");

        state <= SOFTWARE_INTERRUPT_TEST;
    endrule

    rule softwareInterruptTest(state == SOFTWARE_INTERRUPT_TEST);
        exceptionController.csrFile.setMachineModeInterruptsEnabled(True);
        let result <- exceptionController.csrFile.writeWithOffset(IE, 'h2002, 0);
        dynamicAssert(result == True, "Unable to write to MIE");
        result <- exceptionController.csrFile.writeWithOffset(IP, 'h2002, 1);
        dynamicAssert(result == True, "Unable to write to MIP");

        state <= SOFTWARE_INTERRUPT_VERIFY;
    endrule

    rule softwareInterruptVerify(state == SOFTWARE_INTERRUPT_VERIFY);
        case(counter)
            0: begin
                let highestPriorityInterrupt <- exceptionController.getHighestPriorityInterrupt(True, 0);
                dynamicAssert(isValid(highestPriorityInterrupt), "No interrupts are active");
                $display("Highest priority interrupt: %d", unJust(highestPriorityInterrupt));
                dynamicAssert(unJust(highestPriorityInterrupt) == 13, "Highest priority interrupt value is incorrect");
            end

            1: begin
                let highestPriorityInterrupt <- exceptionController.getHighestPriorityInterrupt(True, 0);
                dynamicAssert(isValid(highestPriorityInterrupt), "No interrupts are active");
                $display("Highest priority interrupt: %d", unJust(highestPriorityInterrupt));
                dynamicAssert(unJust(highestPriorityInterrupt) == 1, "Highest priority interrupt value is incorrect");
            end

            2: begin
                let highestPriorityInterrupt <- exceptionController.getHighestPriorityInterrupt(True, 0);
                dynamicAssert(isValid(highestPriorityInterrupt) == False, "There should be no other interrupts pending");
            end

            default: 
                state <= COMPLETE;
        endcase

        counter <= counter + 1;
    endrule

    rule complete(state == COMPLETE);
        $display("    PASS");
        $finish();
    endrule
endmodule
