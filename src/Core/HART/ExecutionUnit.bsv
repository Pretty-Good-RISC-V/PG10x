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

export ExecutionUnit(..), mkExecutionUnit, mkExecutionUnitV2, mkExecutionUnitTester;

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

function ExecutedInstruction newExecutedInstructionFromDecodedInstructionNEW(DecodedInstruction decodedInstruction);
    ExecutedInstruction executedInstruction = newExecutedInstruction(decodedInstruction.instructionCommon.programCounter, decodedInstruction.instructionCommon.rawInstruction);
    executedInstruction.instructionCommon.fetchIndex = decodedInstruction.instructionCommon.fetchIndex;
    executedInstruction.instructionCommon.pipelineEpoch = decodedInstruction.instructionCommon.pipelineEpoch;
    executedInstruction.instructionCommon.predictedNextProgramCounter = decodedInstruction.instructionCommon.predictedNextProgramCounter;

    // If there's an exception in the incoming deccoded instruction, pass it to
    // the executed instruction, otherwise, keep the illegal instruction exception
    // that's created by default.
    if (decodedInstruction.exception matches tagged Valid .exception) begin
        executedInstruction.exception = decodedInstruction.exception;
    end else begin
        executedInstruction.exception = tagged Invalid;
    end

    return executedInstruction;
endfunction

function Bool isValidInstructionAddress(ProgramCounter programCounter);
    return (programCounter[1:0] == 0 ? True : False);
endfunction

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

module mkExecutionUnit#(
    PipelineController pipelineController,
    TrapController trapController,
    Scoreboard#(4) scoreboard
)(ExecutionUnit);
    // Primary output FIFO
    FIFO#(ExecutedInstruction) outputQueue <- mkPipelineFIFO;

    // Secondary output bypass FIFOs
    FIFO#(RVGPRIndex) executionDestinationQueue <- mkBypassFIFO;
    FIFO#(Word) executionResultQueue <- mkBypassFIFO;
    FIFO#(RVGPRIndex) loadDestinationQueue <- mkBypassFIFO;
    FIFO#(ProgramCounter) branchRedirectionQueue <- mkBypassFIFO;

    // ALU
    ALU alu <- mkALU;

    //
    // ALU
    //
    function ActionValue#(ExecutedInstruction) executeALU(DecodedInstruction decodedInstruction, ExecutedInstruction executedInstruction);
        actionvalue
            dynamicAssert(isValid(decodedInstruction.rs1), "ALU: rs1 is invalid");

            let result = alu.execute(
                decodedInstruction.aluOperator, 
                decodedInstruction.rs1Value,
                fromMaybe(decodedInstruction.rs2Value, decodedInstruction.immediate)
            );

            if (result matches tagged Valid .rdValue) begin
                executedInstruction.gprWriteback = tagged Success GPRWriteback {
                    rd: decodedInstruction.rd,
                    value: rdValue
                };
                executedInstruction.exception = tagged Invalid;
            end else begin
                executedInstruction.gprWriteback = tagged Error createIllegalInstructionException(decodedInstruction.instructionCommon.rawInstruction);
            end

            return executedInstruction;
        endactionvalue
    endfunction

    //
    // BRANCH
    //
    function ActionValue#(ExecutedInstruction) executeBRANCH(DecodedInstruction decodedInstruction, Address branchTarget, ExecutedInstruction executedInstruction);
        actionvalue
            dynamicAssert(isValid(decodedInstruction.rs1), "BRANCH: rs1 is invalid");
            dynamicAssert(isValid(decodedInstruction.rs2), "BRANCH: rs2 is invalid");
            dynamicAssert(isValid(decodedInstruction.immediate), "BRANCH: immediate is invalid");

            if (isValidBranchOperator(decodedInstruction.branchOperator) &&&
                decodedInstruction.immediate matches tagged Valid .immediate) begin
                Maybe#(ProgramCounter) nextProgramCounter = tagged Invalid;
                if (isBranchTaken(decodedInstruction)) begin
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
                    executedInstruction.redirectedProgramCounter = tagged Success npc;
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
            dynamicAssert(isValid(decodedInstruction.rs1) == False, "COPY_IMMEDIATE: rs1 SHOULD BE invalid");
            dynamicAssert(isValid(decodedInstruction.rs2) == False, "COPY_IMMEDIATE: rs2 SHOULD BE invalid");
            dynamicAssert(isValid(decodedInstruction.immediate), "COPY_IMMEDIATE: immediate is invalid");

            executedInstruction.gprWriteback = tagged Success GPRWriteback {
                rd: decodedInstruction.rd,
                value: unJust(decodedInstruction.immediate)
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
                dynamicAssert(isValid(decodedInstruction.csrIndex), "CSRIndex is invalid");

                let operand = fromMaybe(decodedInstruction.rs1Value, decodedInstruction.immediate);
                let csrIndex = unJust(decodedInstruction.csrIndex);
                let csrWriteEnabled = (isValid(decodedInstruction.immediate) || unJust(decodedInstruction.rs1) != 0);
                let rd = decodedInstruction.rd;

                let immediateIsZero = (isValid(decodedInstruction.immediate) ? unJust(decodedInstruction.immediate) == 0 : False);

                let currentValue = decodedInstruction.csrValue;
                executedInstruction.gprWriteback = tagged Success GPRWriteback {
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
                        executedInstruction.csrWriteback = tagged Success CSRWriteback {
                            rd: csrIndex,
                            value: v
                        };
                        executedInstruction.exception = tagged Invalid;
                    end else begin
                        `stageLog(decodedInstruction.instructionCommon, DecodeStageNumber, "ERROR - attempted to write to a read-only CSR")

                        executedInstruction.exception = tagged Valid createIllegalInstructionException(decodedInstruction.instructionCommon.rawInstruction);
                        executedInstruction.gprWriteback = tagged Error createIllegalInstructionException(decodedInstruction.instructionCommon.rawInstruction);
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
    function ActionValue#(ExecutedInstruction) executeJUMP(DecodedInstruction decodedInstruction, Address jumpTarget, ExecutedInstruction executedInstruction);
        actionvalue
            dynamicAssert(isValid(decodedInstruction.rs1) == False, "JUMP: rs1 SHOULD BE invalid");
            dynamicAssert(isValid(decodedInstruction.rs2) == False, "JUMP: rs2 SHOULD BE invalid");
            dynamicAssert(isValid(decodedInstruction.immediate), "JUMP: immediate is invalid");

            `stageLog(decodedInstruction.instructionCommon, ExecutionStageNumber, $format("JumpTarget: $%0x", jumpTarget))

            if (isValidInstructionAddress(jumpTarget) == False) begin
                executedInstruction.exception = tagged Valid createMisalignedInstructionException(jumpTarget);
                executedInstruction.gprWriteback = tagged Error createMisalignedInstructionException(jumpTarget);
            end else begin
                executedInstruction.redirectedProgramCounter = tagged Success jumpTarget;
                executedInstruction.gprWriteback = tagged Success GPRWriteback {
                    rd: decodedInstruction.rd,
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
            dynamicAssert(isValid(decodedInstruction.rs1), "JUMP_INDIRECT: rs1 is invalid");
            dynamicAssert(isValid(decodedInstruction.rs2) == False, "JUMP_INDIRECT: rs2 SHOULD BE invalid");
            dynamicAssert(isValid(decodedInstruction.immediate), "JUMP_INDIRECT: immediate is invalid");
                
            let immediate = unJust(decodedInstruction.immediate);
            let jumpTarget = getEffectiveAddress(decodedInstruction.rs1Value, immediate);
            jumpTarget[0] = 0;

            `stageLog(decodedInstruction.instructionCommon, ExecutionStageNumber, $format("JUMP_INDIRECT: RS1: $%0x - Offset: $%0x - JumpTarget: $%0x", decodedInstruction.rs1Value, immediate, jumpTarget))

            if (isValidInstructionAddress(jumpTarget) == False) begin
                executedInstruction.exception = tagged Valid createMisalignedInstructionException(jumpTarget);
                executedInstruction.gprWriteback = tagged Error createMisalignedInstructionException(jumpTarget);
            end else begin
                executedInstruction.redirectedProgramCounter = tagged Success jumpTarget;
                executedInstruction.gprWriteback = tagged Success GPRWriteback {
                    rd: decodedInstruction.rd,
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
    function ActionValue#(ExecutedInstruction) executeLOAD(DecodedInstruction decodedInstruction, Address effectiveAddress, ExecutedInstruction executedInstruction);
        actionvalue
            dynamicAssert(isValid(decodedInstruction.rs1), "LOAD: rs1 is invalid");
            dynamicAssert(isValid(decodedInstruction.rs2) == False, "LOAD: rs2 SHOULD BE invalid");
            dynamicAssert(isValid(decodedInstruction.immediate), "LOAD: immediate is invalid");

            let rd = decodedInstruction.rd;

            let result = createLoadRequest(
                decodedInstruction.loadOperator,
                rd,
                effectiveAddress
            );

            `stageLog(decodedInstruction.instructionCommon, ExecutionStageNumber, 
                $format("LOAD LEA: $%0x - $%0x", effectiveAddress, decodedInstruction.loadOperator))

            if (isSuccess(result)) begin
                executedInstruction.loadRequest = tagged Success result.Success;
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
    function ActionValue#(ExecutedInstruction) executeSTORE(DecodedInstruction decodedInstruction, Address effectiveAddress, ExecutedInstruction executedInstruction);
        actionvalue
            dynamicAssert(isValid(decodedInstruction.rs1), "STORE: rs1 is invalid");
            dynamicAssert(isValid(decodedInstruction.rs2), "STORE: rs2 is invalid");
            dynamicAssert(isValid(decodedInstruction.immediate), "STORE: immediate is invalid");

            `stageLog(decodedInstruction.instructionCommon, ExecutionStageNumber, $format("STORE effective address: $%x", effectiveAddress))

            let result = createStoreRequest(
                decodedInstruction.storeOperator,
                effectiveAddress,
                decodedInstruction.rs2Value
            );

            if (isSuccess(result)) begin
                executedInstruction.storeRequest = tagged Success result.Success;
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
                        executedInstruction.redirectedProgramCounter = tagged Success newProgramCounter;
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
            if (executedInstruction.redirectedProgramCounter matches tagged Success .targetAddress &&& targetAddress != executedInstruction.instructionCommon.predictedNextProgramCounter) begin
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
            if (executedInstruction.gprWriteback matches tagged Success .wb) begin
                `stageLog(executedInstruction.instructionCommon, ExecutionStageNumber, $format("Setting NORMAL GPR writeback index to $%0d = $%0x", wb.rd, wb.value))
                executionDestinationQueue.enq(wb.rd);
                executionResultQueue.enq(wb.value);
            end

            if (executedInstruction.loadRequest matches tagged Success .lr) begin
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

            let immediate = unJust(decodedInstruction.immediate);
            let loadStoreEffectiveAddress = getEffectiveAddress(decodedInstruction.rs1Value, immediate);
            let branchJumpTargetAddress = getEffectiveAddress(decodedInstruction.instructionCommon.programCounter, immediate);

            // Check for an existing pending interrupt.
            let highestPriorityInterrupt <- trapController.getHighestPriorityInterrupt(True, 1);
            if (highestPriorityInterrupt matches tagged Valid .highest) begin
                executedInstruction.exception = tagged Valid createInterruptException(decodedInstruction.instructionCommon.programCounter, extend(highest));
            end else begin
                case(decodedInstruction.opcode)
                    ALU:            executedInstruction <- executeALU(decodedInstruction, executedInstruction);
                    BRANCH:         executedInstruction <- executeBRANCH(decodedInstruction, branchJumpTargetAddress, executedInstruction);
                    COPY_IMMEDIATE: executedInstruction <- executeCOPY_IMMEDIATE(decodedInstruction, executedInstruction);
                    CSR:            executedInstruction <- executeCSR(decodedInstruction, executedInstruction);
                    FENCE:          executedInstruction = executeFENCE(decodedInstruction, executedInstruction);
                    JUMP:           executedInstruction <- executeJUMP(decodedInstruction, branchJumpTargetAddress, executedInstruction);
                    JUMP_INDIRECT:  executedInstruction <- executeJUMP_INDIRECT(decodedInstruction, executedInstruction);
                    LOAD:           executedInstruction <- executeLOAD(decodedInstruction, loadStoreEffectiveAddress, executedInstruction);
                    STORE:          executedInstruction <- executeSTORE(decodedInstruction, loadStoreEffectiveAddress, executedInstruction);
                    SYSTEM:         executedInstruction <- executeSYSTEM(decodedInstruction, executedInstruction);
                endcase
            end

            return executedInstruction;
        endactionvalue
    endfunction

    interface Put putDecodedInstruction;
        method Action put(DecodedInstruction decodedInstruction);
            Maybe#(RVCSRIndex) csrScoreboardValue = tagged Invalid;

            if (!pipelineController.isCurrentEpoch(valueOf(ExecutionStageNumber), 1, decodedInstruction.instructionCommon.pipelineEpoch)) begin
                // Stale instruction, change the instruction into a NO-OP and let it continue through the pipeline.
                `stageLog(decodedInstruction.instructionCommon, ExecutionStageNumber, "stale instruction...adding bubble to pipeline")

                let noopInstruction = newNOOPExecutedInstruction(decodedInstruction.instructionCommon.programCounter);
                outputQueue.enq(noopInstruction);
            end else if(isValid(decodedInstruction.exception)) begin
                // An exception was found in the incoming instruction - propagate it.
                `stageLog(decodedInstruction.instructionCommon, ExecutionStageNumber, "EXCEPTION - decoded instruction had exception - propagating")

                outputQueue.enq(newExecutedInstructionFromDecodedInstruction(decodedInstruction));
            end else begin
                `stageLog(decodedInstruction.instructionCommon, ExecutionStageNumber, $format("executing instruction: ", fshow(decodedInstruction.opcode)))
                `stageLog(decodedInstruction.instructionCommon, ExecutionStageNumber, $format("RS1: ", (isValid(decodedInstruction.rs1) ? $format("x%0d = %0d ($%0x)", unJust(decodedInstruction.rs1), decodedInstruction.rs1Value, decodedInstruction.rs1Value) : $format("INVALID"))))
                `stageLog(decodedInstruction.instructionCommon, ExecutionStageNumber, $format("RS2: ", (isValid(decodedInstruction.rs2) ? $format("x%0d = %0d ($%0x)", unJust(decodedInstruction.rs2), decodedInstruction.rs2Value, decodedInstruction.rs2Value) : $format("INVALID"))))
                `stageLog(decodedInstruction.instructionCommon, ExecutionStageNumber, $format("RD : x%0d", decodedInstruction.rd))

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

`define DISABLE_PIPELINE_CONTROLLER

module mkExecutionUnitV2#(
    PipelineController pipelineController,
    TrapController trapController,
    Scoreboard#(4) scoreboard
)(ExecutionUnit);
    // Primary input register
    Reg#(DecodedInstruction) decodedInstruction <- mkRegU;

    // Secondary output bypass FIFOs
    FIFO#(RVGPRIndex) executionDestinationQueue <- mkBypassFIFO;
    FIFO#(Word) executionResultQueue <- mkBypassFIFO;
    FIFO#(RVGPRIndex) loadDestinationQueue <- mkBypassFIFO;
    FIFO#(ProgramCounter) branchRedirectionQueue <- mkBypassFIFO;

    let branchJumpTargetAddress = getEffectiveAddressWithMaybe(
        decodedInstruction.instructionCommon.programCounter, 
        decodedInstruction.immediate
    );

    let indirectJumpTargetAddress = {branchJumpTargetAddress[valueOf(XLEN)-1:1], 1'b0};

    //
    // Redirected Program Counter
    //
    function Result#(ProgramCounter, Exception) getRedirectedProgramCounter;
        return case(decodedInstruction.opcode)
            BRANCH: begin
                if (isValidBranchOperator(decodedInstruction.branchOperator) &&& decodedInstruction.immediate matches tagged Valid .immediate) begin
                    Result#(ProgramCounter, Exception) result = tagged Invalid;
                    Maybe#(ProgramCounter) nextProgramCounter = tagged Invalid;
                    if (isBranchTaken(decodedInstruction)) begin
                        // Branch target must be 32 bit aligned.
                        if (isValidInstructionAddress(branchJumpTargetAddress) == False) begin
                            result = tagged Error createMisalignedInstructionException(branchJumpTargetAddress);
                        end else begin
                            nextProgramCounter = tagged Valid branchJumpTargetAddress;
                        end
                    end else begin
                        nextProgramCounter = tagged Valid (decodedInstruction.instructionCommon.programCounter + 4);
                    end

                    if (nextProgramCounter matches tagged Valid .npc &&& npc != decodedInstruction.instructionCommon.predictedNextProgramCounter) begin
                        result = tagged Success npc;
                    end

                    return result;
                end else begin
                    return tagged Error createIllegalInstructionException(decodedInstruction.instructionCommon.rawInstruction);
                end
            end

            JUMP: begin
                return tagged Success branchJumpTargetAddress;
            end

            JUMP_INDIRECT: begin
                return tagged Success indirectJumpTargetAddress;
            end

            default: begin
                return tagged Invalid;
            end
        endcase;
    endfunction

    let loadStoreEffectiveAddress = getEffectiveAddressWithMaybe(
        decodedInstruction.rs1Value, 
        decodedInstruction.immediate
    );

    //
    // LOAD
    //
    function Result#(LoadRequest, Exception) getLoadRequest;
        Result#(LoadRequest, Exception) loadRequest = tagged Invalid;
        if (decodedInstruction.opcode == LOAD) begin
            loadRequest = createLoadRequest(
                decodedInstruction.loadOperator,
                decodedInstruction.rd,
                loadStoreEffectiveAddress
            );
        end
        return loadRequest;
    endfunction

    //
    // STORE
    // 
    function Result#(StoreRequest, Exception) getStoreRequest;
        Result#(StoreRequest, Exception) storeRequest = tagged Invalid;
        if (decodedInstruction.opcode == STORE) begin
            storeRequest = createStoreRequest(
                decodedInstruction.storeOperator,
                loadStoreEffectiveAddress,
                decodedInstruction.rs2Value
            );
        end
        return storeRequest;
    endfunction

    // CSR
    let csrOperatorValid = (decodedInstruction.csrOperator[1:0] != 0);
    let csrWriteEnabled = (isValid(decodedInstruction.immediate) || unJust(decodedInstruction.rs1) != 0);
    let csrWriteRequested = (decodedInstruction.csrOperator[1:0] != 0);
    let csrIndex = unJust(decodedInstruction.csrIndex);
    let csrWriteValid =  trapController.csrFile.isWritable(csrIndex);

    let csrOperand = fromMaybe(decodedInstruction.rs1Value, decodedInstruction.immediate);
    let immediateIsZero = (isValid(decodedInstruction.immediate) ? unJust(decodedInstruction.immediate) == 0 : False);
    let csrClearValue = decodedInstruction.csrValue & ~csrOperand;
    let csrSetValue = decodedInstruction.csrValue | csrOperand;

    Maybe#(Word) csrWriteValue = case(decodedInstruction.csrOperator[1:0])
        'b01: begin // CSRRW(I)
            return tagged Valid csrOperand;
        end
        'b10: begin // CSRRS(I)
            if (csrWriteEnabled && !immediateIsZero && csrOperand != 0) begin
                return tagged Valid csrSetValue;
            end else begin
                return tagged Invalid;
            end
        end
        'b11: begin // CSRRC(I)
            if (csrWriteEnabled && !immediateIsZero && csrOperand != 0) begin
                return tagged Valid csrClearValue;
            end else begin
                return tagged Invalid;
            end
        end
        default: begin
            return tagged Invalid;
        end
    endcase;

    function Result#(GPRWriteback, Exception) getCSR_GPRWriteback;
        if (!csrOperatorValid) begin
            return tagged Error createIllegalInstructionException(decodedInstruction.instructionCommon.rawInstruction);
        end else begin
            if (csrWriteRequested && csrWriteEnabled) begin
               if (!trapController.csrFile.isWritable(csrIndex)) begin
                    return tagged Error createIllegalInstructionException(decodedInstruction.instructionCommon.rawInstruction);
               end else begin
                    return tagged Success GPRWriteback {
                        rd: decodedInstruction.rd,
                        value: decodedInstruction.csrValue
                    };
               end
            end else begin
                return tagged Success GPRWriteback {
                    rd: decodedInstruction.rd,
                    value: decodedInstruction.csrValue
                };            
            end
        end
    endfunction

    function Result#(CSRWriteback, Exception) getCSRWriteback;
        if(decodedInstruction.opcode != CSR) begin
            return tagged Invalid;
        end else if (!csrOperatorValid) begin
            return tagged Error createIllegalInstructionException(decodedInstruction.instructionCommon.rawInstruction);
        end else begin
            if (csrWriteValue matches tagged Valid .v &&& csrWriteValid) begin
                return tagged Success CSRWriteback {
                    rd: csrIndex,
                    value: v
                };
            end else begin
                return tagged Invalid;
            end
        end
    endfunction

    ALU alu <- mkALU;

    //
    // GPRWriteback
    //
    function Result#(GPRWriteback, Exception) getGPRWriteback;
        return case(decodedInstruction.opcode)
            //
            // ALU
            //
            ALU: begin
                let result = alu.execute(
                    decodedInstruction.aluOperator, 
                    decodedInstruction.rs1Value,
                    fromMaybe(decodedInstruction.rs2Value, decodedInstruction.immediate)
                );

                if (result matches tagged Valid .rdValue) begin
                    return tagged Success GPRWriteback {
                        rd: decodedInstruction.rd,
                        value: rdValue
                    };
                end else begin
                    return tagged Error 
                        createIllegalInstructionException(decodedInstruction.instructionCommon.rawInstruction);
                end
            end

            //
            // COPY_IMMEDIATE
            //
            COPY_IMMEDIATE: begin
                return tagged Success GPRWriteback {
                    rd: decodedInstruction.rd,
                    value: unJust(decodedInstruction.immediate)
                };
            end

            //
            // CSR
            //
            CSR: begin
                return getCSR_GPRWriteback;
            end

            //
            // JUMP
            //
            JUMP: begin
                if (isValidInstructionAddress(branchJumpTargetAddress)) begin
                    return tagged Success GPRWriteback {
                        rd: decodedInstruction.rd,
                        value: (decodedInstruction.instructionCommon.programCounter + 4)
                    };
                end else begin
                    return tagged Error createMisalignedInstructionException(branchJumpTargetAddress);
                end
            end
            
            //
            // JUMP_INDIRECT
            //
            JUMP_INDIRECT: begin
                if (isValidInstructionAddress(indirectJumpTargetAddress)) begin
                    return tagged Success GPRWriteback {
                        rd: decodedInstruction.rd,
                        value: (decodedInstruction.instructionCommon.programCounter + 4)
                    };
                end else begin
                    return tagged Error createMisalignedInstructionException(branchJumpTargetAddress);
                end
            end

            default: begin
                return tagged Invalid;
            end
        endcase;
    endfunction

    //
    // GPR writeback
    //
    interface Put putDecodedInstruction = toPut(asIfc(decodedInstruction));
    interface Get getExecutedInstruction;
        method ActionValue#(ExecutedInstruction) get;
            let executedInstruction = newExecutedInstructionFromDecodedInstructionNEW(decodedInstruction);
            if (executedInstruction.exception matches tagged Invalid) begin
                executedInstruction.redirectedProgramCounter = getRedirectedProgramCounter;
                executedInstruction.loadRequest = getLoadRequest;
                executedInstruction.storeRequest = getStoreRequest;
                executedInstruction.gprWriteback = getGPRWriteback;
                executedInstruction.csrWriteback = getCSRWriteback;

                // If the program counter was changed, see if it matches a predicted branch/jump.
                // If not, redirect the program counter to the mispredicted target address.
                if (executedInstruction.redirectedProgramCounter matches tagged Success .targetAddress &&& targetAddress != executedInstruction.instructionCommon.predictedNextProgramCounter) begin
                    // Bump the current instruction epoch
`ifndef DISABLE_PIPELINE_CONTROLLER
//                    pipelineController.flush(1);
`endif
                    executedInstruction.instructionCommon.pipelineEpoch = ~executedInstruction.instructionCommon.pipelineEpoch;

                    //`stageLog(executedInstruction.instructionCommon, ExecutionStageNumber, $format("branch/jump to: $%08x: ", targetAddress))
                    
                    //branchRedirectionQueue.enq(targetAddress);
                end
            end
            return executedInstruction;
        endmethod
    endinterface

    interface Get getBranchProgramCounterRedirection = toGet(branchRedirectionQueue);
    interface Get getExecutionDestination = toGet(executionDestinationQueue);
    interface Get getExecutionResult = toGet(executionResultQueue);
    interface Get getLoadDestination = toGet(loadDestinationQueue);
endmodule

module mkExecutionUnitTester#(
    PipelineController pipelineController,
    TrapController trapController,
    Scoreboard#(4) scoreboard
)(ExecutionUnit);
    ExecutionUnit executionUnit1 <- mkExecutionUnit(pipelineController, trapController, scoreboard);
    ExecutionUnit executionUnit2 <- mkExecutionUnitV2(pipelineController, trapController, scoreboard);

    // Input
    interface Put putDecodedInstruction;
        method Action put(DecodedInstruction decodedInstruction);
            executionUnit1.putDecodedInstruction.put(decodedInstruction);
            executionUnit2.putDecodedInstruction.put(decodedInstruction);
        endmethod
    endinterface

    // Output (primary)
    interface Get getExecutedInstruction;
        method ActionValue#(ExecutedInstruction) get;
            let executedInstruction1 <- executionUnit1.getExecutedInstruction.get;
            let executedInstruction2 <- executionUnit2.getExecutedInstruction.get;

            if (executedInstruction1 != executedInstruction2) begin
                $display("Executed Instruction Mismatch at PC $%0x", executedInstruction1.instructionCommon.programCounter);
                $display("I1: ", fshow(executedInstruction1));
                $display("I1: ", fshow(pack(executedInstruction1)));
                $display("I2: ", fshow(executedInstruction2));
                $display("I2: ", fshow(pack(executedInstruction2)));
                $fatal();
            end

            return executedInstruction1;
        endmethod
    endinterface

    // Outputs (secondary)
    interface Get getBranchProgramCounterRedirection = executionUnit1.getBranchProgramCounterRedirection;
    interface Get getExecutionDestination = executionUnit1.getExecutionDestination;
    interface Get getExecutionResult = executionUnit1.getExecutionResult;
    interface Get getLoadDestination = executionUnit1.getLoadDestination;
endmodule