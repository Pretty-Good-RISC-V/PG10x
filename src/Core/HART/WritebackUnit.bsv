//
// WritebackUnit
//
// This module handles writing back instruction results back to the register file.
//
import PGTypes::*;

import CSRFile::*;
import Exception::*;
import ExceptionController::*;
import ExecutedInstruction::*;
import GPRFile::*;
`ifdef ENABLE_INSTRUCTION_LOGGING
import InstructionLogger::*;
`endif
import PipelineController::*;
import ProgramCounterRedirect::*;

import DReg::*;
import FIFO::*;
import GetPut::*;
import SpecialFIFOs::*;

export WritebackUnit(..), mkWritebackUnit;

interface WritebackUnit;
    interface Put#(Word64) putCycleCounter;
    interface Put#(ExecutedInstruction) putExecutedInstruction;
    method Bool wasInstructionRetired;

`ifdef ENABLE_RISCOF_TESTS
    interface Get#(Bool) getRISCOFHaltRequested;
`endif
endinterface

module mkWritebackUnit#(
    Integer stageNumber,
    PipelineController pipelineController,
    ProgramCounterRedirect programCounterRedirect,
    GPRFile gprFile,
    ExceptionController exceptionController
)(WritebackUnit);
    Wire#(Word64) cycleCounter <- mkBypassWire;
    Reg#(Bool) instructionRetired <- mkDReg(False);

`ifdef ENABLE_RISCOF_TESTS
    Reg#(Bool) riscofHaltRequested <- mkReg(False);
`endif

`ifdef ENABLE_INSTRUCTION_LOGGING
    InstructionLog instructionLog<- mkInstructionLog;
`endif

    interface Put putExecutedInstruction;
`ifdef ENABLE_RISCOF_TESTS    
        method Action put(ExecutedInstruction executedInstruction) if(riscofHaltRequested == False);
`else
        method Action put(ExecutedInstruction executedInstruction);
`endif        
            Bool verbose <- $test$plusargs ("verbose");
            let fetchIndex = executedInstruction.fetchIndex;
            let stageEpoch = pipelineController.stageEpoch(stageNumber, 0);

            if (!pipelineController.isCurrentEpoch(stageNumber, 0, executedInstruction.pipelineEpoch)) begin
                if (verbose)
                    $display("%0d,%0d,%0d,%0d,%0d,writeback,stale instruction...popping bubble", fetchIndex, cycleCounter, stageEpoch, executedInstruction.programCounter, stageNumber);
            end else begin
                if (executedInstruction.writeBack matches tagged Valid .wb) begin
                    if (verbose)
                        $display("%0d,%0d,%0d,%0x,%0d,writeback,writing result ($%08x) to register x%0d", fetchIndex, cycleCounter, stageEpoch, executedInstruction.programCounter, stageNumber, wb.value, wb.rd);
                    gprFile.write(wb.rd, wb.value);
                end else begin
                    if (verbose)
                        $display("%0d,%0d,%0d,%0x,%0d,writeback,NO-OP", fetchIndex, cycleCounter, stageEpoch, executedInstruction.programCounter, stageNumber);
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

                //
                // Handle any exceptions
                //
                if (executedInstruction.exception matches tagged Valid .exception) begin
                    pipelineController.flush(0);

                    let exceptionVector <- exceptionController.beginException(executedInstruction.programCounter, exception);

                    if (verbose) begin
                        $display("%0d,%0d,%0d,%0x,%0d,writeback,EXCEPTION:", fetchIndex, cycleCounter, stageEpoch, executedInstruction.programCounter, stageNumber, fshow(exception));
                        $display("%0d,%0d,%0d,%0x,%0d,writeback,Jumping to exception handler at $%08x", fetchIndex, cycleCounter, stageEpoch, executedInstruction.programCounter, stageNumber, exceptionVector);
                    end
                    programCounterRedirect.exception(exceptionVector); 

`ifdef ENABLE_RISCOF_TESTS
                    if (exception.cause matches tagged ExceptionCause .cause &&& cause == exception_RISCOFTestHaltException) begin
                        if (verbose)
                            $display("%0d,%0d,%0d,%0x,%0d,writeback,RISCOF HALT Requested", fetchIndex, cycleCounter, stageEpoch, executedInstruction.programCounter, stageNumber);
                        riscofHaltRequested <= True;
                    end
`endif                    
                end
                if (verbose)
                    $display("%0d,%0d,%0d,%0x,%0d,writeback,---------------------------", fetchIndex, cycleCounter, stageEpoch, executedInstruction.programCounter, stageNumber);
                exceptionController.csrFile.increment_instructions_retired_counter;
                instructionRetired <= True;
            end
        endmethod
    endinterface

    method Bool wasInstructionRetired;
        return instructionRetired;
    endmethod

    interface Put putCycleCounter = toPut(asIfc(cycleCounter));

`ifdef ENABLE_RISCOF_TESTS
    interface Get getRISCOFHaltRequested = toGet(riscofHaltRequested);
`endif

endmodule
