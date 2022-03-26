import PGTypes::*;

import CSRFile::*;
import Exception::*;

import Assert::*;
import GetPut::*;

export ExceptionController(..), mkExceptionController, CSRFile::*;

interface ExceptionController;
    interface CSRFile csrFile;

    method ActionValue#(ProgramCounter) beginException(ProgramCounter exceptionProgramCounter, Exception exception);
    method ActionValue#(Maybe#(Bit#(TSub#(XLEN, 1)))) getHighestPriorityInterrupt(Bool clear, Integer portNumber);
endinterface

module mkExceptionController(ExceptionController);
    CSRFile innerCsrFile <- mkCSRFile;

    function Integer findHighestSetBit(Word a);
        Integer highestBit = -1;
        for (Integer bitNumber = valueOf(XLEN) - 1; bitNumber >= 0; bitNumber = bitNumber - 1)
            if (a[bitNumber] != 0 && highestBit == -1) begin
                highestBit = bitNumber;
            end
        return highestBit;
    endfunction

    method ActionValue#(ProgramCounter) beginException(ProgramCounter exceptionProgramCounter, Exception exception);
        Word cause = 0;
        let curPriv <- innerCsrFile.getCurrentPrivilegeLevel.get;

        case(exception.cause) matches
            tagged ExceptionCause .c: begin
                cause[valueOf(XLEN)-2:0] = c;
            end

            tagged InterruptCause .c: begin
                cause[valueOf(XLEN)-1] = 1;
                cause[valueOf(XLEN)-2:0] = c;
            end

            tagged EnvironmentCallCause .c: begin
                cause[valueOf(XLEN)-2:0] = exception_ENVIRONMENT_CALL_FROM_U_MODE + extend(curPriv);
            end

            default: begin
                $display("ERROR: Unexpected exception cause during exception handling");
                $fatal();
            end
        endcase

        // !todo:
        // xPIE
        // xPP
        innerCsrFile.writeWithOffset1(csr_EPC, exceptionProgramCounter);        
        innerCsrFile.writeWithOffset1(csr_CAUSE, cause);
        innerCsrFile.writeWithOffset1(csr_TVAL, exception.tval);
        Word vectorTableBase = unJust(innerCsrFile.readWithOffset1(csr_TVEC));
        let exceptionHandler = vectorTableBase;

        // Check and handle a vectored trap handler table
        if (exceptionHandler[1:0] == 1) begin
            exceptionHandler[1:0] = 0;
            if(exception.cause matches tagged InterruptCause .interruptCause) begin
                exceptionHandler = exceptionHandler + extend(4 * interruptCause);
            end
        end

        return exceptionHandler;
    endmethod

    interface CSRFile csrFile = innerCsrFile;

    method ActionValue#(Maybe#(Bit#(TSub#(XLEN, 1)))) getHighestPriorityInterrupt(Bool clear, Integer portNumber);
        Maybe#(Bit#(TSub#(XLEN, 1))) result = tagged Invalid;

        let machineModeInterrptsEnabled <- innerCsrFile.getMachineModeInterruptsEnabled.get;
        if (machineModeInterrptsEnabled) begin
            let mie = fromMaybe(0, innerCsrFile.read1(csr_MIE));
            let mip = fromMaybe(0, innerCsrFile.read1(csr_MIP));

            let actionableInterrupts = mip & mie;
            if (actionableInterrupts != 0) begin
                let highestBit = findHighestSetBit(actionableInterrupts);
                $display("Interrupt (%0d) is pending - MIE: $%0x, MIP: $%0x", highestBit, mie, mip);
                if (highestBit != -1) begin
                    result = tagged Valid fromInteger(highestBit);

                    if (clear) begin
                        let newMIP = mip & ~(1 << highestBit);
                        let writeResult <- innerCsrFile.write1(csr_MIP, newMIP);
                        dynamicAssert(writeResult == True, "MIP Write failed!");
                    end
                end
            end
        end

        return result;
    endmethod
endmodule
