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
import PipelineController::*;
import ProgramCounterRedirect::*;
import RegisterFile::*;
import Scoreboard::*;

import DReg::*;
import FIFO::*;
import GetPut::*;
import SpecialFIFOs::*;

export WritebackUnit(..), mkWritebackUnit;

interface WritebackUnit;
    method Bool wasInstructionRetired;
endinterface

module mkWritebackUnit#(
    Reg#(Word64) cycleCounter,
    Integer stageNumber,
    PipelineController pipelineController,
    FIFO#(ExecutedInstruction) inputQueue,
    ProgramCounterRedirect programCounterRedirect,
    Scoreboard#(4) scoreboard, 
    RegisterFile registerFile,
    CSRFile csrFile,
    ExceptionController exceptionController,
    Reg#(RVPrivilegeLevel) currentPrivilegeLevel
)(WritebackUnit);
    Reg#(Bool) instructionRetired <- mkDReg(False);

    (* fire_when_enabled *)
    rule writeBack;
        let executedInstruction = inputQueue.first();
        let fetchIndex = executedInstruction.fetchIndex;
        let stageEpoch = pipelineController.stageEpoch(stageNumber, 0);

        if (!pipelineController.isCurrentEpoch(stageNumber, 0, executedInstruction.pipelineEpoch)) begin
            $display("%0d,%0d,%0d,%0d,writeback,stale instruction (%0d != %0d)...ignoring", fetchIndex, cycleCounter, executedInstruction.pipelineEpoch, inputQueue.first().programCounter, stageNumber, inputQueue.first().pipelineEpoch, stageEpoch);
            inputQueue.deq();
        end else begin
            inputQueue.deq();
            if (executedInstruction.writeBack matches tagged Valid .wb) begin
                $display("%0d,%0d,%0d,%0d,%0d,writeback,writing result ($%08x) to register x%0d", fetchIndex, cycleCounter, stageEpoch, executedInstruction.programCounter, stageNumber, wb.value, wb.rd);
                registerFile.write(wb.rd, wb.value);
            end else begin
                $display("%0d,%0d,%0d,%0d,%0d,writeback,NO-OP", fetchIndex, cycleCounter, stageEpoch, executedInstruction.programCounter, stageNumber);
            end

            scoreboard.remove;

            //
            // Handle any exceptions
            //
            if (executedInstruction.exception matches tagged Valid .exception) begin
                pipelineController.flush(0);

                let exceptionVector <- exceptionController.beginException(currentPrivilegeLevel, executedInstruction.programCounter, exception);

                $display("%0d,%0d,%0d,%0d,%0d,writeback,EXCEPTION:", fetchIndex, cycleCounter, stageEpoch, executedInstruction.programCounter, stageNumber, fshow(exception));
                $display("%0d,%0d,%0d,%0d,%0d,writeback,Jumping to exception handler at $%08x", fetchIndex, cycleCounter, stageEpoch, executedInstruction.programCounter, stageNumber, exceptionVector);

                programCounterRedirect.exception(exceptionVector); 
            end
            $display("%0d,%0d,%0d,%0d,%0d,writeback,---------------------------", fetchIndex, cycleCounter, stageEpoch, executedInstruction.programCounter, stageNumber);
            csrFile.increment_instructions_retired_counter();
            instructionRetired <= True;
        end
    endrule

    method Bool wasInstructionRetired;
        return instructionRetired;
    endmethod
endmodule
