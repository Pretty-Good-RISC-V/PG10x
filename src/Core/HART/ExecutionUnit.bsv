//
// ExecutionUnit
//
// This module is a RISC-V instruction execution unit.  It is responsible for executing instructions 
// described by a 'DecodedInstruction' structure resulting in a 'ExecutedInstruction' structure. 
//
`include "PGLib.bsvi"
`include "HART.bsvi"

import ALU::*;
import DecodedInstruction::*;
import Exception::*;
import TrapController::*;
import ExecutedInstruction::*;
import InstructionCommon::*;
import LoadStore::*;
import Scoreboard::*;
import StageNumbers::*;

import Assert::*;
import FIFO::*;
import GetPut::*;
import SpecialFIFOs::*;

export ExecutionUnit(..), mkExecutionUnit;

interface ExecutionUnit;
    // Input
    interface Put#(DecodedInstruction) putDecodedInstruction;

    // Output (primary)
    interface Get#(ExecutedInstruction) getExecutedInstruction;

    // Outputs (secondary)
    interface Get#(ProgramCounter)  getBranchProgramCounterRedirection;
    interface Get#(RVGPRIndex)      getExecutionDestination;
    interface Get#(Word)            getExecutionResult;
    interface Get#(RVGPRIndex)      getLoadDestination;
endinterface

module mkExecutionUnit#(
    PipelineController pipelineController,
    TrapController trapController,
    Scoreboard#(4) scoreboard
)(ExecutionUnit);
    // Primary output FIFO
    FIFO#(ExecutedInstruction) outputQueue <- mkPipelineFIFO;

    // Secondary output FIFOs
    FIFO#(RVGPRIndex) executionDestinationQueue <- mkBypassFIFO;
    FIFO#(Word) executionResultQueue <- mkBypassFIFO;
    FIFO#(RVGPRIndex) loadDestinationQueue <- mkBypassFIFO;
    FIFO#(ProgramCounter) branchRedirectionQueue <- mkBypassFIFO;

    ALU alu <- mkALU;

    function ExecutedInstruction newExecutedInstructionFromDecodedInstruction(DecodedInstruction decodedInstruction);
        ExecutedInstruction executedInstruction = newExecutedInstruction(decodedInstruction.instructionCommon.programCounter, decodedInstruction.instructionCommon.rawInstruction);
        executedInstruction.instructionCommon.fetchIndex = decodedInstruction.instructionCommon.fetchIndex;
        executedInstruction.instructionCommon.pipelineEpoch = decodedInstruction.instructionCommon.pipelineEpoch;
        executedInstruction.instructionCommon.predictedNextProgramCounter = decodedInstruction.instructionCommon.predictedNextProgramCounter;

        // If there's an exception in the incoming deccoded instruction, pass it to
        // the executed instruction, otherwise, keep the illegal instruction exception
        // that's created by default.
        if (decodedInstruction.exception matches tagged Valid .exception) begin
            executedInstruction.exception = decodedInstruction.exception;
        end

        return executedInstruction;
    endfunction

    function Bool isValidInstructionAddress(ProgramCounter programCounter);
        return (programCounter[1:0] == 0 ? True : False);
    endfunction

    //
    // ALU
    //
    function ActionValue#(ExecutedInstruction) executeALU(DecodedInstruction decodedInstruction, ExecutedInstruction executedInstruction);
        actionvalue
            dynamicAssert(isValid(decodedInstruction.rd), "ALU: rd is invalid");
            dynamicAssert(isValid(decodedInstruction.rs1), "ALU: rs1 is invalid");

            let result = alu.execute(
                decodedInstruction.aluOperator, 
                decodedInstruction.rs1Value,
                fromMaybe(decodedInstruction.rs2Value, decodedInstruction.immediate)
            );

            if (result matches tagged Valid .rdValue) begin
                executedInstruction.gprWriteBack = tagged Valid GPRWriteBack {
                    rd: unJust(decodedInstruction.rd),
                    value: rdValue
                };
                executedInstruction.exception = tagged Invalid;
            end

            return executedInstruction;
        endactionvalue
    endfunction

    //
    // BRANCH
    //
    function Bool isValidBranchOperator(RVBranchOperator operator);
        return ((operator != branch_UNSUPPORTED_010 &&
                operator != branch_UNSUPPORTED_011) ? True : False);
    endfunction

    function Bool isBranchTaken(DecodedInstruction decodedInstruction);
        return case(decodedInstruction.branchOperator)
            branch_BEQ: return (decodedInstruction.rs1Value == decodedInstruction.rs2Value);
            branch_BNE: return (decodedInstruction.rs1Value != decodedInstruction.rs2Value);
            branch_BLT: return (signedLT(decodedInstruction.rs1Value, decodedInstruction.rs2Value));
            branch_BGE: return (signedGE(decodedInstruction.rs1Value, decodedInstruction.rs2Value));
            branch_BGEU: return (decodedInstruction.rs1Value >= decodedInstruction.rs2Value);
            branch_BLTU: return (decodedInstruction.rs1Value < decodedInstruction.rs2Value);
        endcase;
    endfunction

    function ActionValue#(ExecutedInstruction) executeBRANCH(DecodedInstruction decodedInstruction, ExecutedInstruction executedInstruction);
        actionvalue
            dynamicAssert(isValid(decodedInstruction.rd) == False, "BRANCH: rd SHOULD BE invalid");
            dynamicAssert(isValid(decodedInstruction.rs1), "BRANCH: rs1 is invalid");
            dynamicAssert(isValid(decodedInstruction.rs2), "BRANCH: rs2 is invalid");
            dynamicAssert(isValid(decodedInstruction.immediate), "BRANCH: immediate is invalid");

            if (isValidBranchOperator(decodedInstruction.branchOperator) &&&
                decodedInstruction.immediate matches tagged Valid .immediate) begin
                Maybe#(ProgramCounter) nextProgramCounter = tagged Invalid;
                if (isBranchTaken(decodedInstruction)) begin
                    // Determine branch target address and check
                    // for address misalignment.
                    let branchTarget = getEffectiveAddress(decodedInstruction.instructionCommon.programCounter, immediate);
                    // Branch target must be 32 bit aligned.
                    if (isValidInstructionAddress(branchTarget) == False) begin
                        executedInstruction.exception = tagged Valid createMisalignedInstructionException(branchTarget);
                    end else begin
                        // Target address aligned
                        executedInstruction.exception = tagged Invalid;
                        nextProgramCounter = tagged Valid branchTarget;
                    end
                end else begin
                    executedInstruction.exception = tagged Invalid;
                    nextProgramCounter = tagged Valid (decodedInstruction.instructionCommon.programCounter + 4);
                end

                if (nextProgramCounter matches tagged Valid .npc &&& npc != decodedInstruction.instructionCommon.predictedNextProgramCounter) begin
                    executedInstruction.changedProgramCounter = tagged Valid npc;
                end
            end

            return executedInstruction;
        endactionvalue
    endfunction

    //
    // COPY_IMMEDIATE
    //
    function ActionValue#(ExecutedInstruction) executeCOPY_IMMEDIATE(DecodedInstruction decodedInstruction, ExecutedInstruction executedInstruction);
        actionvalue
            dynamicAssert(isValid(decodedInstruction.rd), "COPY_IMMEDIATE: rd is invalid");
            dynamicAssert(isValid(decodedInstruction.rs1) == False, "COPY_IMMEDIATE: rs1 SHOULD BE invalid");
            dynamicAssert(isValid(decodedInstruction.rs2) == False, "COPY_IMMEDIATE: rs2 SHOULD BE invalid");
            dynamicAssert(isValid(decodedInstruction.immediate), "COPY_IMMEDIATE: immediate is invalid");

            executedInstruction.gprWriteBack = tagged Valid GPRWriteBack {
                rd: fromMaybe(?, decodedInstruction.rd),
                value: fromMaybe(?, decodedInstruction.immediate)
            };
            executedInstruction.exception = tagged Invalid;

            return executedInstruction;
        endactionvalue
    endfunction

    //
    // CSR
    //
    function ActionValue#(ExecutedInstruction) executeCSR(DecodedInstruction decodedInstruction, ExecutedInstruction executedInstruction);
        actionvalue
            if (decodedInstruction.csrOperator[1:0] != 0) begin
                dynamicAssert(isValid(decodedInstruction.rd), "RD is invalid");
                dynamicAssert(isValid(decodedInstruction.csrIndex), "CSRIndex is invalid");

                let operand = fromMaybe(decodedInstruction.rs1Value, decodedInstruction.immediate);
                let csrIndex = unJust(decodedInstruction.csrIndex);
                let csrWriteEnabled = (isValid(decodedInstruction.immediate) || unJust(decodedInstruction.rs1) != 0);
                let rd = unJust(decodedInstruction.rd);

                let immediateIsZero = (isValid(decodedInstruction.immediate) ? unJust(decodedInstruction.immediate) == 0 : False);

                let currentValue = decodedInstruction.csrValue;
                executedInstruction.gprWriteBack = tagged Valid GPRWriteBack {
                    rd: rd,
                    value: currentValue
                };

                let clearBits = currentValue & ~operand;
                let setBits = currentValue | operand;
                Maybe#(Word) writeValue = tagged Invalid;

                case(decodedInstruction.csrOperator[1:0])
                    'b01: begin // CSRRW(I)
                        writeValue = tagged Valid operand;
                    end
                    'b10: begin // CSRRS(I)
                        if (csrWriteEnabled && !immediateIsZero && operand != 0) begin
                            writeValue = tagged Valid setBits;
                        end
                    end
                    'b11: begin // CSRRC(I)
                        if (csrWriteEnabled && !immediateIsZero && operand != 0) begin
                            writeValue = tagged Valid clearBits;
                        end
                    end
                endcase

                if (writeValue matches tagged Valid .v) begin
                    if (trapController.csrFile.isWritable(csrIndex)) begin
                        executedInstruction.csrWriteBack = tagged Valid CSRWriteBack {
                            rd: csrIndex,
                            value: unJust(writeValue)
                        };
                        executedInstruction.exception = tagged Invalid;
                    end else begin
                        `stageLog(decodedInstruction.instructionCommon, DecodeStageNumber, "ERROR - attempted to write to a read-only CSR")

                        executedInstruction.exception = tagged Valid createIllegalInstructionException(decodedInstruction.instructionCommon.rawInstruction);
                        executedInstruction.gprWriteBack = tagged Invalid;
                    end
                end else begin
                    executedInstruction.exception = tagged Invalid;
                end
            end

            return executedInstruction;
        endactionvalue
    endfunction

    //
    // FENCE
    //
    function ExecutedInstruction executeFENCE(
        DecodedInstruction decodedInstruction,
        ExecutedInstruction executedInstruction);

        executedInstruction.exception = tagged Invalid;
        return executedInstruction;
    endfunction

    //
    // JUMP
    //
    function ActionValue#(ExecutedInstruction) executeJUMP(DecodedInstruction decodedInstruction, ExecutedInstruction executedInstruction);
        actionvalue
            dynamicAssert(isValid(decodedInstruction.rd), "JUMP: rd is invalid");
            dynamicAssert(isValid(decodedInstruction.rs1) == False, "JUMP: rs1 SHOULD BE invalid");
            dynamicAssert(isValid(decodedInstruction.rs2) == False, "JUMP: rs2 SHOULD BE invalid");
            dynamicAssert(isValid(decodedInstruction.immediate), "JUMP: immediate is invalid");

            let immediate = unJust(decodedInstruction.immediate);
            let jumpTarget = getEffectiveAddress(decodedInstruction.instructionCommon.programCounter, immediate);

            `stageLog(decodedInstruction.instructionCommon, ExecutionStageNumber, $format("JUMP: RS1: $%0x - Offset: $%0x - JumpTarget: $%0x", decodedInstruction.rs1Value, immediate, jumpTarget))

            if (isValidInstructionAddress(jumpTarget) == False) begin
                executedInstruction.exception = tagged Valid createMisalignedInstructionException(jumpTarget);
            end else begin
                executedInstruction.changedProgramCounter = tagged Valid jumpTarget;
                executedInstruction.gprWriteBack = tagged Valid GPRWriteBack {
                    rd: fromMaybe(?, decodedInstruction.rd),
                    value: (decodedInstruction.instructionCommon.programCounter + 4)
                };
                executedInstruction.exception = tagged Invalid;
            end
            return executedInstruction;
        endactionvalue
    endfunction

    //
    // JUMP_INDIRECT
    //
    function ActionValue#(ExecutedInstruction) executeJUMP_INDIRECT(DecodedInstruction decodedInstruction, ExecutedInstruction executedInstruction);
        actionvalue
            dynamicAssert(isValid(decodedInstruction.rd), "JUMP_INDIRECT: rd is invalid");
            dynamicAssert(isValid(decodedInstruction.rs1), "JUMP_INDIRECT: rs1 is invalid");
            dynamicAssert(isValid(decodedInstruction.rs2) == False, "JUMP_INDIRECT: rs2 SHOULD BE invalid");
            dynamicAssert(isValid(decodedInstruction.immediate), "JUMP_INDIRECT: immediate is invalid");
                
            let immediate = unJust(decodedInstruction.immediate);
            let jumpTarget = getEffectiveAddress(decodedInstruction.rs1Value, immediate);
            jumpTarget[0] = 0;

            `stageLog(decodedInstruction.instructionCommon, ExecutionStageNumber, $format("JUMP_INDIRECT: RS1: $%0x - Offset: $%0x - JumpTarget: $%0x", decodedInstruction.rs1Value, immediate, jumpTarget))

            if (isValidInstructionAddress(jumpTarget) == False) begin
                executedInstruction.exception = tagged Valid createMisalignedInstructionException(jumpTarget);
            end else begin
                executedInstruction.changedProgramCounter = tagged Valid jumpTarget;
                executedInstruction.gprWriteBack = tagged Valid GPRWriteBack {
                    rd: fromMaybe(?, decodedInstruction.rd),
                    value: (decodedInstruction.instructionCommon.programCounter + 4)
                };
                executedInstruction.exception = tagged Invalid;
            end

            return executedInstruction;
        endactionvalue
    endfunction

    //
    // LOAD
    //
    function ActionValue#(ExecutedInstruction) executeLOAD(DecodedInstruction decodedInstruction, ExecutedInstruction executedInstruction);
        actionvalue
            dynamicAssert(isValid(decodedInstruction.rd), "LOAD: rd is invalid");
            dynamicAssert(isValid(decodedInstruction.rs1), "LOAD: rs1 is invalid");
            dynamicAssert(isValid(decodedInstruction.rs2) == False, "LOAD: rs2 SHOULD BE invalid");
            dynamicAssert(isValid(decodedInstruction.immediate), "LOAD: immediate is invalid");

            let effectiveAddress = getEffectiveAddress(decodedInstruction.rs1Value, unJust(decodedInstruction.immediate));
            let rd = unJust(decodedInstruction.rd);

            let result = getLoadRequest(
                decodedInstruction.loadOperator,
                rd,
                effectiveAddress
            );

            `stageLog(decodedInstruction.instructionCommon, ExecutionStageNumber, 
                $format("LOAD LEA: $%0x - $%0x", effectiveAddress, decodedInstruction.loadOperator))

            if (isSuccess(result)) begin
                executedInstruction.loadRequest = tagged Valid result.Success;
                executedInstruction.exception = tagged Invalid;
            end else begin
                executedInstruction.exception = tagged Valid result.Error;
            end
            return executedInstruction;
        endactionvalue
    endfunction

    //
    // STORE
    //
    function ActionValue#(ExecutedInstruction) executeSTORE(DecodedInstruction decodedInstruction, ExecutedInstruction executedInstruction);
        actionvalue
            dynamicAssert(isValid(decodedInstruction.rd) == False, "STORE: rd is valid");
            dynamicAssert(isValid(decodedInstruction.rs1), "STORE: rs1 is invalid");
            dynamicAssert(isValid(decodedInstruction.rs2), "STORE: rs2 is invalid");
            dynamicAssert(isValid(decodedInstruction.immediate), "STORE: immediate is invalid");

            let effectiveAddress = getEffectiveAddress(decodedInstruction.rs1Value, unJust(decodedInstruction.immediate));

            `stageLog(decodedInstruction.instructionCommon, ExecutionStageNumber, $format("STORE effective address: $%x", effectiveAddress))

            let result = getStoreRequest(
                decodedInstruction.storeOperator,
                effectiveAddress,
                decodedInstruction.rs2Value
            );

            if (isSuccess(result)) begin
                executedInstruction.storeRequest = tagged Valid result.Success;
                executedInstruction.exception = tagged Invalid;
            end else begin
                executedInstruction.exception = tagged Valid result.Error;
            end 
            return executedInstruction;
        endactionvalue
    endfunction

    //
    // SYSTEM
    //
    function ActionValue#(ExecutedInstruction) executeSYSTEM(DecodedInstruction decodedInstruction, ExecutedInstruction executedInstruction);
        actionvalue
            case(decodedInstruction.systemOperator)
                sys_ECALL: begin
                    `stageLog(decodedInstruction.instructionCommon, ExecutionStageNumber, "ECALL instruction encountered")

                    let curPriv <- trapController.csrFile.getCurrentPrivilegeLevel.get;
                    executedInstruction.exception = tagged Valid createEnvironmentCallException(curPriv, decodedInstruction.instructionCommon.programCounter);
                end
                sys_EBREAK: begin
                    `stageLog(decodedInstruction.instructionCommon, ExecutionStageNumber, "EBREAK instruction encountered")

                    executedInstruction.exception = tagged Valid createBreakpointException(decodedInstruction.instructionCommon.programCounter);
                end
                sys_MRET: begin
                    `stageLog(decodedInstruction.instructionCommon, ExecutionStageNumber, "MRET instruction encountered")
                    
                    let newProgramCounterReadStatus <- trapController.endTrap;
                    if (newProgramCounterReadStatus matches tagged Valid .newProgramCounter) begin
                        executedInstruction.changedProgramCounter = tagged Valid newProgramCounter;
                        executedInstruction.exception = tagged Invalid;
                    end else begin
                        executedInstruction.exception = tagged Valid createIllegalInstructionException(decodedInstruction.instructionCommon.rawInstruction);
                    end
                end
                default begin
                    executedInstruction.exception = tagged Invalid;
                end
            endcase
            return executedInstruction;
        endactionvalue
    endfunction

    function Action finalizeInstruction(ExecutedInstruction executedInstruction);
        action
            let fetchIndex = executedInstruction.instructionCommon.fetchIndex;
            let currentEpoch = pipelineController.stageEpoch(valueOf(ExecutionStageNumber), 1);

            // If the program counter was changed, see if it matches a predicted branch/jump.
            // If not, redirect the program counter to the mispredicted target address.
            if (executedInstruction.changedProgramCounter matches tagged Valid .targetAddress &&& targetAddress != executedInstruction.instructionCommon.predictedNextProgramCounter) begin
                // Bump the current instruction epoch
                pipelineController.flush(1);

                executedInstruction.instructionCommon.pipelineEpoch = ~executedInstruction.instructionCommon.pipelineEpoch;

                `stageLog(executedInstruction.instructionCommon, ExecutionStageNumber, $format("branch/jump to: $%08x: ", targetAddress))
                
                branchRedirectionQueue.enq(targetAddress);
            end

            if (executedInstruction.exception matches tagged Valid .exception) begin
                `stageLog(executedInstruction.instructionCommon, ExecutionStageNumber, $format("exception: ", fshow(exception)))
            end

            // If writeback data exists, that needs to be written into the previous pipeline 
            // stages using operand forwarding.
            if (executedInstruction.gprWriteBack matches tagged Valid .wb) begin
                `stageLog(executedInstruction.instructionCommon, ExecutionStageNumber, $format("Setting NORMAL GPR writeback index to $%0d = $%0x", wb.rd, wb.value))
                executionDestinationQueue.enq(wb.rd);
                executionResultQueue.enq(wb.value);
            end

            if (executedInstruction.loadRequest matches tagged Valid .lr) begin
                `stageLog(executedInstruction.instructionCommon, ExecutionStageNumber, $format("Setting LOAD GPR writeback index to $%0d", lr.rd))
                loadDestinationQueue.enq(lr.rd);
            end
            outputQueue.enq(executedInstruction);
        endaction
    endfunction

    function ActionValue#(ExecutedInstruction) executeInstruction(
        DecodedInstruction decodedInstruction);
        actionvalue
            let executedInstruction = newExecutedInstructionFromDecodedInstruction(decodedInstruction);

            // Check for an existing pending interrupt.
            let highestPriorityInterrupt <- trapController.getHighestPriorityInterrupt(True, 1);
            if (highestPriorityInterrupt matches tagged Valid .highest) begin
                executedInstruction.exception = tagged Valid createInterruptException(decodedInstruction.instructionCommon.programCounter, extend(highest));
            end else begin
                case(decodedInstruction.opcode)
                    ALU:            executedInstruction <- executeALU(decodedInstruction, executedInstruction);
                    BRANCH:         executedInstruction <- executeBRANCH(decodedInstruction, executedInstruction);
                    COPY_IMMEDIATE: executedInstruction <- executeCOPY_IMMEDIATE(decodedInstruction, executedInstruction);
                    CSR:            executedInstruction <- executeCSR(decodedInstruction, executedInstruction);
                    FENCE:          executedInstruction = executeFENCE(decodedInstruction, executedInstruction);
                    JUMP:           executedInstruction <- executeJUMP(decodedInstruction, executedInstruction);
                    JUMP_INDIRECT:  executedInstruction <- executeJUMP_INDIRECT(decodedInstruction, executedInstruction);
                    LOAD:           executedInstruction <- executeLOAD(decodedInstruction, executedInstruction);
                    STORE:          executedInstruction <- executeSTORE(decodedInstruction, executedInstruction);
                    SYSTEM:         executedInstruction <- executeSYSTEM(decodedInstruction, executedInstruction);
                endcase
            end

            return executedInstruction;
        endactionvalue
    endfunction

    interface Put putDecodedInstruction;
        method Action put(DecodedInstruction decodedInstruction);
            let fetchIndex = decodedInstruction.instructionCommon.fetchIndex;
            let stageEpoch = pipelineController.stageEpoch(valueOf(ExecutionStageNumber), 1);
            Maybe#(RVCSRIndex) csrScoreboardValue = tagged Invalid;

            if (!pipelineController.isCurrentEpoch(valueOf(ExecutionStageNumber), 1, decodedInstruction.instructionCommon.pipelineEpoch)) begin
                `stageLog(decodedInstruction.instructionCommon, ExecutionStageNumber, $format("stale instruction (%0d != %0d)...adding bubble to pipeline", decodedInstruction.instructionCommon.pipelineEpoch, stageEpoch))

                let noopInstruction = newNOOPExecutedInstruction(decodedInstruction.instructionCommon.programCounter);
                outputQueue.enq(noopInstruction);
            end else if (isValid(decodedInstruction.exception)) begin
                `stageLog(decodedInstruction.instructionCommon, ExecutionStageNumber, "EXCEPTION - decoded instruction had exception - propagating")

                outputQueue.enq(newExecutedInstructionFromDecodedInstruction(decodedInstruction));
            end else begin
                let currentEpoch = stageEpoch;

                `stageLog(decodedInstruction.instructionCommon, ExecutionStageNumber, $format("executing instruction: ", fshow(decodedInstruction.opcode)))
                `stageLog(decodedInstruction.instructionCommon, ExecutionStageNumber, $format("RS1: ", (isValid(decodedInstruction.rs1) ? $format("x%0d = %0d ($%0x)", unJust(decodedInstruction.rs1), decodedInstruction.rs1Value, decodedInstruction.rs1Value) : $format("INVALID"))))
                `stageLog(decodedInstruction.instructionCommon, ExecutionStageNumber, $format("RS2: ", (isValid(decodedInstruction.rs2) ? $format("x%0d = %0d ($%0x)", unJust(decodedInstruction.rs2), decodedInstruction.rs2Value, decodedInstruction.rs2Value) : $format("INVALID"))))
                `stageLog(decodedInstruction.instructionCommon, ExecutionStageNumber, $format("RD : ", (isValid(decodedInstruction.rd) ? $format("x%0d", unJust(decodedInstruction.rd)) : $format("INVALID"))))

                let executedInstruction <- executeInstruction(decodedInstruction);

                finalizeInstruction(executedInstruction);
                csrScoreboardValue = decodedInstruction.csrIndex;
            end
            scoreboard.insertCSR(csrScoreboardValue);
        endmethod
    endinterface

    interface Get getExecutedInstruction = toGet(outputQueue);

    interface Get getBranchProgramCounterRedirection = toGet(branchRedirectionQueue);
    interface Get getExecutionDestination = toGet(executionDestinationQueue);
    interface Get getExecutionResult = toGet(executionResultQueue);
    interface Get getLoadDestination = toGet(loadDestinationQueue);
endmodule
