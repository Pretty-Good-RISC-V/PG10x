//
// WritebackUnit
//
// This module handles writing back instruction results back to the register file.
//
import PGTypes::*;

import CSRFile::*;
import Exception::*;
import TrapController::*;
import ExecutedInstruction::*;
import GPRFile::*;
`ifdef ENABLE_INSTRUCTION_LOGGING
import InstructionLogger::*;
`endif
import PipelineController::*;
import Scoreboard::*;
import StageNumbers::*;

import Assert::*;
import DReg::*;
import FIFO::*;
import GetPut::*;
import SpecialFIFOs::*;

export WritebackUnit(..), mkWritebackUnit;

interface WritebackUnit;
    interface Put#(Word64) putCycleCounter;
    interface Get#(ProgramCounter) getExceptionProgramCounterRedirection;
    interface Put#(ExecutedInstruction) putExecutedInstruction;
    interface Get#(Bool) getInstructionRetired;

`ifdef ENABLE_RISCOF_TESTS
    interface Get#(Bool) getRISCOFHaltRequested;
`endif
endinterface

module mkWritebackUnit#(
    PipelineController pipelineController,
    GPRFile gprFile,
    TrapController trapController,
    Scoreboard#(4) scoreboard
)(WritebackUnit);
    Wire#(Word64) cycleCounter <- mkBypassWire;
    Reg#(Bool) instructionRetired <- mkDReg(False);
    FIFO#(ProgramCounter) exceptionRedirectionQueue <- mkBypassFIFO;

`ifdef ENABLE_RISCOF_TESTS
    Reg#(Bool) riscofHaltRequested <- mkReg(False);
`endif

`ifdef ENABLE_INSTRUCTION_LOGGING
    InstructionLog instructionLog <- mkInstructionLog;
`endif

    FIFO#(Bool) instructionRetiredQueue <- mkFIFO;

    interface Put putExecutedInstruction;
`ifdef ENABLE_RISCOF_TESTS    
        method Action put(ExecutedInstruction executedInstruction) if(riscofHaltRequested == False);
`else
        method Action put(ExecutedInstruction executedInstruction);
`endif        
            Bool verbose <- $test$plusargs ("verbose");
            let fetchIndex = executedInstruction.fetchIndex;
            let stageEpoch = pipelineController.stageEpoch(valueOf(WritebackStageNumber), 0);

            if (executedInstruction.gprWriteBack matches tagged Valid .wb) begin
                if (verbose)
                    $display("%0d,%0d,%0d,%0x,%0d,writeback,writing result ($%08x) to GPR register x%0d", fetchIndex, cycleCounter, stageEpoch, executedInstruction.programCounter, valueOf(WritebackStageNumber), wb.value, wb.rd);
                gprFile.write(wb.rd, wb.value);
                
            end else begin
                if (verbose)
                    $display("%0d,%0d,%0d,%0x,%0d,writeback,NO-OP", fetchIndex, cycleCounter, stageEpoch, executedInstruction.programCounter, valueOf(WritebackStageNumber));
            end

`ifdef ENABLE_INSTRUCTION_LOGGING
            Bool logIt = True;
            if (executedInstruction.exception matches tagged Valid .exception &&&
                exception.cause matches tagged InterruptCause .*) begin
                    // If the instruction was interrupted, don't log it.
                    logIt = False;
            end

            if (executedInstruction.exception matches tagged Valid .exception &&& 
                exception.cause matches tagged ExceptionCause .exceptionCause &&& 
                exceptionCause == exception_INSTRUCTION_ACCESS_FAULT) begin
                    // Don't log instructions that caused fetch faults (as these weren't executed)
                    logIt = False;
            end

            if (logIt)
                instructionLog.logInstruction(executedInstruction.programCounter, executedInstruction.rawInstruction);
`endif

            scoreboard.remove;
            // NOTE: This logic ** ASSUMES ** that if a csrWriteBack exists then there is *NO*
            // exception present.   This is done to isolate the paths that write to CSRs (exception vs. CSR writeback)
            if (executedInstruction.csrWriteBack matches tagged Valid .wb) begin
                dynamicAssert(isValid(executedInstruction.exception) == False, "ERROR: CSR Writeback exists when an exception is present");
                if (verbose)
                    $display("%0d,%0d,%0d,%0x,%0d,writeback,writing result ($%08x) to CSR register $%0x", fetchIndex, cycleCounter, stageEpoch, executedInstruction.programCounter, valueOf(WritebackStageNumber), wb.value, wb.rd);
                let writeResult <- trapController.csrFile.write1(wb.rd, wb.value);
                dynamicAssert(writeResult == True, "ERROR: Failed to write to CSR via writeback");
            end else begin
                //
                // Handle any exceptions
                //
                if (executedInstruction.exception matches tagged Valid .exception) begin
                    pipelineController.flush(0);

                    let exceptionVector <- trapController.beginTrap(executedInstruction.programCounter, exception);

                    if (verbose) begin
                        $display("%0d,%0d,%0d,%0x,%0d,writeback,EXCEPTION:", fetchIndex, cycleCounter, stageEpoch, executedInstruction.programCounter, valueOf(WritebackStageNumber), fshow(exception));
                        $display("%0d,%0d,%0d,%0x,%0d,writeback,Jumping to exception handler at $%08x", fetchIndex, cycleCounter, stageEpoch, executedInstruction.programCounter, valueOf(WritebackStageNumber), exceptionVector);
                    end
                    exceptionRedirectionQueue.enq(exceptionVector);

`ifdef ENABLE_RISCOF_TESTS
                    if (exception.cause matches tagged ExceptionCause .cause &&& cause == exception_RISCOFTestHaltException) begin
                        if (verbose)
                            $display("%0d,%0d,%0d,%0x,%0d,writeback,RISCOF HALT Requested", fetchIndex, cycleCounter, stageEpoch, executedInstruction.programCounter, valueOf(WritebackStageNumber));
                        riscofHaltRequested <= True;
                    end
`endif                    
                end

                if (verbose)
                    $display("%0d,%0d,%0d,%0x,%0d,writeback,---------------------------", fetchIndex, cycleCounter, stageEpoch, executedInstruction.programCounter, valueOf(WritebackStageNumber));
                trapController.csrFile.increment_instructions_retired_counter;

                instructionRetiredQueue.enq(True);
            end
        endmethod
    endinterface

    interface Put putCycleCounter = toPut(asIfc(cycleCounter));

    interface Get getExceptionProgramCounterRedirection = toGet(exceptionRedirectionQueue);

    interface Get getInstructionRetired = toGet(instructionRetiredQueue);

`ifdef ENABLE_RISCOF_TESTS
    interface Get getRISCOFHaltRequested = toGet(riscofHaltRequested);
`endif

endmodule
