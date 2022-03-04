import PGTypes::*;

import CSRFile::*;
import Exception::*;

import Assert::*;

export ExceptionController(..), mkExceptionController, CSRFile::*;

interface ExceptionController;
    interface CSRFile csrFile;

    method ActionValue#(ProgramCounter) beginException(ProgramCounter exceptionProgramCounter, Exception exception);
    method ActionValue#(Maybe#(Word32)) getHighestPriorityInterrupt(Bool clear, Integer portNumber);
endinterface

module mkExceptionController(ExceptionController);
    CSRFile csrFileInner <- mkCSRFile;

    function Integer findHighestSetBit(Word a);
        Integer highestBit = -1;
        for (Integer bitNumber = valueOf(XLEN) - 1; bitNumber >= 0; bitNumber = bitNumber - 1)
            if (a[bitNumber] != 0 && highestBit == -1) begin
                highestBit = bitNumber;
            end
        return highestBit;
    endfunction

    method ActionValue#(ProgramCounter) beginException(ProgramCounter exceptionProgramCounter, Exception exception);
        let cause = getCause(exception);

        csrFileInner.writeWithOffset(CAUSE, cause, 0);
        csrFileInner.writeWithOffset(EPC, exceptionProgramCounter, 0);

        Word vectorTableBase = unJust(csrFileInner.readWithOffset(TVEC, 0));
        let exceptionHandler = vectorTableBase;
        if (exceptionHandler[1:0] == 1) begin
            exceptionHandler[1:0] = 0;
            if(exception matches tagged InterruptCause .interruptCause) begin
                exceptionHandler = exceptionHandler + extend(4 * interruptCause);
            end
        end

        return exceptionHandler;
    endmethod

    interface CSRFile csrFile = csrFileInner;

    method ActionValue#(Maybe#(Word32)) getHighestPriorityInterrupt(Bool clear, Integer portNumber);
        Maybe#(Word32) result = tagged Invalid;

        if (csrFileInner.machineModeInterruptsEnabled) begin
            let mie = fromMaybe(0, csrFileInner.read(pack(MIE), portNumber));
            let mip = fromMaybe(0, csrFileInner.read(pack(MIP), portNumber));

            let actionableInterrupts = mip & mie;
            if (actionableInterrupts != 0) begin
                let highestBit = findHighestSetBit(actionableInterrupts);
                $display("Interrupt (%0d) is pending - MIE: $%0x, MIP: $%0x", highestBit, mie, mip);
                if (highestBit != -1) begin
                    result = tagged Valid fromInteger(highestBit);

                    if (clear) begin
                        let newMIP = mip & ~(1 << highestBit);
                        let writeResult <- csrFileInner.write(pack(MIP), newMIP, portNumber);
                        dynamicAssert(writeResult == True, "MIP Write failed!");
                    end
                end
            end
        end

        return result;
    endmethod
endmodule
