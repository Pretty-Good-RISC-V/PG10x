import PGTypes::*;

import CSRFile::*;
import Exception::*;
import MachineISA::*;
import MachineStatus::*;

import Assert::*;
import GetPut::*;

export ExceptionController(..), mkExceptionController, CSRFile::*;

interface ExceptionController;
    interface CSRFile csrFile;

    method ActionValue#(ProgramCounter) beginTrap(ProgramCounter exceptionProgramCounter, Exception exception);
    method ActionValue#(ProgramCounter) endTrap;

    method ActionValue#(Maybe#(Bit#(TSub#(XLEN, 1)))) getHighestPriorityInterrupt(Bool clear, Integer portNumber);
endinterface

module mkExceptionController(ExceptionController);
    CSRFile innerCsrFile <- mkCSRFile;

    // Based on fv_new_priv_on_exception from Flute processor.
    function RVPrivilegeLevel getTrapPrivilegeLevel(
        Exception exception,
        RVPrivilegeLevel currentPrivilegeLevel,
        MachineStatus mstatus,
        MachineISA misa,
        Word mideleg,
        Word medeleg,
        Word sideleg,
        Word sedeleg);

        let trapPrivilegeLevel = priv_MACHINE;
        let delegated = False;

        if (currentPrivilegeLevel < priv_MACHINE) begin
            if (misa.extS) begin    // S mode supported?
                // See if this trap should be delegated to SUPERVISOR mode
                delegated = case(exception.cause) matches
                    tagged InterruptCause .cause: begin
                        return (mideleg[cause] == 0 ? False : True);
                    end

                    tagged ExceptionCause .cause: begin
                        return (medeleg[cause] == 0 ? False : True);
                    end
                endcase;

                if (delegated) begin
                    trapPrivilegeLevel = priv_SUPERVISOR;

                    // If the current priv mode is U, and user mode traps are supported,
	                // then consult sedeleg/sideleg to determine if delegated to USER mode.                    
                    if (currentPrivilegeLevel == priv_USER && misa.extN) begin
                        delegated = case(exception.cause) matches
                            tagged InterruptCause .cause: begin
                                return (sideleg[cause] == 0 ? False : True);
                            end

                            tagged ExceptionCause .cause: begin
                                return (sedeleg[cause] == 0 ? False : True);
                            end
                        endcase;

                        if (delegated) begin
                            trapPrivilegeLevel = priv_USER;
                        end
                    end
                end
            end else begin // S mode *NOT* supported
                // If user mode traps are supported, then consult sedeleg/sideleg to determine 
                // if delegated to USER mode.                    

                if (misa.extN) begin
                    delegated = case(exception.cause) matches
                        tagged InterruptCause .cause: begin
                            return (mideleg[cause] == 0 ? False : True);
                        end

                        tagged ExceptionCause .cause: begin
                            return (medeleg[cause] == 0 ? False : True);
                        end
                    endcase;

                    if (delegated) begin
                        trapPrivilegeLevel = priv_USER;
                    end
                end
            end
        end

        return trapPrivilegeLevel;
    endfunction

    function Integer findHighestSetBit(Word a);
        Integer highestBit = -1;
        for (Integer bitNumber = valueOf(XLEN) - 1; bitNumber >= 0; bitNumber = bitNumber - 1)
            if (a[bitNumber] != 0 && highestBit == -1) begin
                highestBit = bitNumber;
            end
        return highestBit;
    endfunction

    method ActionValue#(ProgramCounter) beginTrap(ProgramCounter exceptionProgramCounter, Exception exception);
        Word cause = 0;
        let curPriv <- innerCsrFile.getCurrentPrivilegeLevel.get;

        // CurPriv => MSTATUS::MPP
        let mstatus = innerCsrFile.getMachineStatus;
        let misa = innerCsrFile.getMachineISA;
        let mideleg = innerCsrFile.getMachineInterruptDelegation;
        let medeleg = innerCsrFile.getMachineExceptionDelegation;

        let trapPrivilegeLevel = getTrapPrivilegeLevel(
            exception,
            curPriv,
            mstatus,
            misa,
            mideleg,
            medeleg,
            0,  // sideleg 
            0   // sedeleg
        );

        case(exception.cause) matches
            tagged ExceptionCause .c: begin
                cause[valueOf(XLEN)-2:0] = c;
            end

            tagged InterruptCause .c: begin
                cause[valueOf(XLEN)-1] = 1;
                cause[valueOf(XLEN)-2:0] = c;
            end

            default: begin
                $display("ERROR: Unexpected exception cause during exception handling");
                $fatal();
            end
        endcase

        // !todo:
        // PC => MEPC
        innerCsrFile.writeWithOffset1(trapPrivilegeLevel, csr_EPC, exceptionProgramCounter);        

        // CurPriv => MSTATUS::MPP
        mstatus.mpp = curPriv;

        // MSTATUS::MIE => MSTATUS::MPIE
        mstatus.mpie = mstatus.mie;
        innerCsrFile.putMachineStatus(mstatus);

        // cause => CAUSE
        innerCsrFile.writeWithOffset1(trapPrivilegeLevel, csr_CAUSE, cause);
        innerCsrFile.writeWithOffset1(trapPrivilegeLevel, csr_TVAL, exception.tval);
        Word vectorTableBase = unJust(innerCsrFile.readWithOffset1(trapPrivilegeLevel, csr_TVEC));
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

    method ActionValue#(ProgramCounter) endTrap;
        return 0;
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
