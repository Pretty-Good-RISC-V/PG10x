import PGTypes::*;

import CSRFile::*;
import Exception::*;
import TrapController::*;

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
module mkTrapController_tb(Empty);
    Reg#(State) state <- mkReg(INIT);
    Reg#(Word) counter <- mkReg(0);

    TrapController trapController <- mkTrapController;

    Word actualExceptionVector = 'h8000;
    ProgramCounter exceptionProgramCounter = 'h4000;
    RVExceptionCause exceptionCause = exception_ILLEGAL_INSTRUCTION;

    rule init(state == INIT);
        let succeeded <- trapController.csrFile.writeWithOffset1(priv_MACHINE, csr_TVEC, actualExceptionVector);
        dynamicAssert(succeeded == True, "Attempt to write MTVEC in machine mode should succeed.");
        state <= VERIFY_INIT;
    endrule

    rule verifyInit(state == VERIFY_INIT);
        let result = trapController.csrFile.readWithOffset2(priv_MACHINE, csr_TVEC);
        dynamicAssert(isValid(result), "Reading MTVEC in machine mode should succeed.");
        dynamicAssert(unJust(result) == actualExceptionVector, "Reading MTVEC should contain value written");

        state <= TEST;
    endrule

    rule beginException(state == TEST);
        Exception exception = Exception {
            cause: tagged ExceptionCause exceptionCause,
            tval: 0
        };
        let receivedExceptionVector <- trapController.beginTrap(exceptionProgramCounter, exception);
        dynamicAssert(receivedExceptionVector == actualExceptionVector, "Exception Vector isn't correct.");

        state <= VERIFY_TEST;
    endrule

    rule endException(state == VERIFY_TEST);
        let mtvec = trapController.csrFile.readWithOffset1(priv_MACHINE, csr_TVEC);
        dynamicAssert(isValid(mtvec), "Reading MTVEC in machine mode should succeed.");
        dynamicAssert(unJust(mtvec) == actualExceptionVector, "Reading MTVEC should contain value written");

        let mecpc = trapController.csrFile.readWithOffset1(priv_MACHINE, csr_EPC);
        dynamicAssert(isValid(mecpc), "Reading MEPC in machine mode should succeed.");
        dynamicAssert(unJust(mecpc) == exceptionProgramCounter, "Reading MEPC should contain value written");

        let mcause = trapController.csrFile.readWithOffset1(priv_MACHINE, csr_CAUSE);
        dynamicAssert(isValid(mcause), "Reading MCAUSE in machine mode should succeed.");

        state <= SOFTWARE_INTERRUPT_TEST;
    endrule

    rule softwareInterruptTest(state == SOFTWARE_INTERRUPT_TEST);
        // Enable machine mode interrupts
        let result = trapController.csrFile.read1(csr_MSTATUS);
        dynamicAssert(isValid(result), "MSTATUS should be readable");

        let mstatus = unJust(result);
        mstatus[3] = 1;
        result <- trapController.csrFile.write1(csr_MSTATUS, mstatus);
        dynamicAssert(result, "MSTATUS should be writable");

        result <- trapController.csrFile.writeWithOffset1(priv_MACHINE, csr_IE, 'h2002);
        dynamicAssert(result == True, "Unable to write to MIE");
        result <- trapController.csrFile.writeWithOffset1(priv_MACHINE, csr_IP, 'h2002);
        dynamicAssert(result == True, "Unable to write to MIP");

        state <= SOFTWARE_INTERRUPT_VERIFY;
    endrule

    rule softwareInterruptVerify(state == SOFTWARE_INTERRUPT_VERIFY);
        case(counter)
            0: begin
                let highestPriorityInterrupt <- trapController.getHighestPriorityInterrupt(True, 0);
                dynamicAssert(isValid(highestPriorityInterrupt), "No interrupts are active");
                $display("Highest priority interrupt: %d", unJust(highestPriorityInterrupt));
                dynamicAssert(unJust(highestPriorityInterrupt) == 13, "Highest priority interrupt value is incorrect");
            end

            1: begin
                let highestPriorityInterrupt <- trapController.getHighestPriorityInterrupt(True, 0);
                dynamicAssert(isValid(highestPriorityInterrupt), "No interrupts are active");
                $display("Highest priority interrupt: %d", unJust(highestPriorityInterrupt));
                dynamicAssert(unJust(highestPriorityInterrupt) == 1, "Highest priority interrupt value is incorrect");
            end

            2: begin
                let highestPriorityInterrupt <- trapController.getHighestPriorityInterrupt(True, 0);
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
