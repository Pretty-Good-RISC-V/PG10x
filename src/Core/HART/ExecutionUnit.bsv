//
// ExecutionUnit
//
// This module is a RISC-V instruction execution unit.  It is responsible for executing instructions 
// described by a 'DecodedInstruction' structure resulting in a 'ExecutedInstruction' structure. 
//
`include "PGLib.bsh"

import ALU::*;
import BypassUnit::*;
import DecodedInstruction::*;
import Exception::*;
import TrapController::*;
import ExecutedInstruction::*;
import LoadStore::*;
import PipelineController::*;
import ProgramCounterRedirect::*;
import Scoreboard::*;

import Assert::*;
import FIFO::*;
import GetPut::*;
import SpecialFIFOs::*;

export ExecutionUnit(..), mkExecutionUnit;

interface ExecutionUnit;
    interface Put#(Word64) putCycleCounter;

    interface Put#(DecodedInstruction) putDecodedInstruction;
    interface Get#(ExecutedInstruction) getExecutedInstruction;

    interface Get#(Maybe#(GPRBypassValue)) getGPRBypassValue;

    interface Put#(Bool) putHalt;
endinterface

module mkExecutionUnit#(
    Integer stageNumber,
    PipelineController pipelineController,
    ProgramCounterRedirect programCounterRedirect,
    TrapController trapController,
    Scoreboard#(4) scoreboard
)(ExecutionUnit);
    Wire#(Word64) cycleCounter <- mkBypassWire;
    FIFO#(ExecutedInstruction) outputQueue <- mkPipelineFIFO;
    RWire#(Maybe#(GPRBypassValue)) gprBypassValue <- mkRWire();
    Reg#(Bool) halt <- mkReg(False);

    ALU alu <- mkALU;

    function ExecutedInstruction newExecutedInstructionFromDecodedInstruction(DecodedInstruction decodedInstruction);
        ExecutedInstruction executedInstruction = newExecutedInstruction(decodedInstruction.programCounter, decodedInstruction.rawInstruction);
        executedInstruction.fetchIndex = decodedInstruction.fetchIndex;
        executedInstruction.pipelineEpoch = decodedInstruction.pipelineEpoch;
        executedInstruction.exception = decodedInstruction.exception;
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
        // NOTE: Validity of the branch operator has already been checked.
        return case(decodedInstruction.branchOperator)
            branch_BEQ: return (decodedInstruction.rs1Value == decodedInstruction.rs2Value);
            branch_BNE: return (decodedInstruction.rs1Value != decodedInstruction.rs2Value);
            branch_BLT: return (signedLT(decodedInstruction.rs1Value, decodedInstruction.rs2Value));
            branch_BGE: return (signedGE(decodedInstruction.rs1Value, decodedInstruction.rs2Value));
            branch_BGEU: return (decodedInstruction.rs1Value >= decodedInstruction.rs2Value);
            branch_BLTU: return (decodedInstruction.rs1Value < decodedInstruction.rs2Value);
        endcase;
    endfunction

    function ActionValue#(ExecutedInstruction) executeCSR(
        DecodedInstruction decodedInstruction,
        ExecutedInstruction executedInstruction
    );
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
                    if (csrWriteEnabled && !immediateIsZero) begin
                        writeValue = tagged Valid setBits;
                    end
                end
                'b11: begin // CSRRC(I)
                    if (csrWriteEnabled && !immediateIsZero) begin
                        writeValue = tagged Valid clearBits;
                    end
                end
            endcase

            if (writeValue matches tagged Valid .v) begin
                executedInstruction.csrWriteBack = tagged Valid CSRWriteBack {
                    rd: csrIndex,
                    value: unJust(writeValue)
                };
            end

            executedInstruction.exception = tagged Invalid;
        end

        return executedInstruction;
        endactionvalue
    endfunction

    function ActionValue#(ExecutedInstruction) executeInstruction(
        DecodedInstruction decodedInstruction,
        PipelineEpoch currentEpoch);
        actionvalue
            Bool verbose <- $test$plusargs ("verbose");

            let executedInstruction = newExecutedInstructionFromDecodedInstruction(decodedInstruction);
            executedInstruction.exception = tagged Valid createIllegalInstructionException(decodedInstruction.rawInstruction);

            // Check for an existing pending interrupt.
            let pendingInterrupt = False;
            let highestPriorityInterrupt <- trapController.getHighestPriorityInterrupt(True, 1);
            if (highestPriorityInterrupt matches tagged Valid .highest) begin
                executedInstruction.exception = tagged Valid createInterruptException(decodedInstruction.programCounter, extend(highest));
                pendingInterrupt = True;
            end

            if (!pendingInterrupt) begin
                case(decodedInstruction.opcode)
                    ALU: begin
                        dynamicAssert(isValid(decodedInstruction.rd), "ALU: rd is invalid");
                        dynamicAssert(isValid(decodedInstruction.rs1), "ALU: rs1 is invalid");

                        let result = alu.execute(
                            decodedInstruction.aluOperator, 
                            decodedInstruction.rs1Value,
                            fromMaybe(decodedInstruction.rs2Value, decodedInstruction.immediate)
                        );

                        if (isValid(result)) begin
                            executedInstruction.gprWriteBack = tagged Valid GPRWriteBack {
                                rd: fromMaybe(?, decodedInstruction.rd),
                                value: fromMaybe(?, result)
                            };
                            executedInstruction.exception = tagged Invalid;
                        end
                    end

`ifdef RV64
                    ALU32: begin
                        dynamicAssert(isValid(decodedInstruction.rd), "ALU: rd is invalid");
                        dynamicAssert(isValid(decodedInstruction.rs1), "ALU: rs1 is invalid");

                        let result = alu.execute32(
                            decodedInstruction.aluOperator, 
                            decodedInstruction.rs1Value,
                            fromMaybe(decodedInstruction.rs2Value, decodedInstruction.immediate)
                        );

                        if (isValid(result)) begin
                            executedInstruction.gprWriteBack = tagged Valid GPRWriteBack {
                                rd: fromMaybe(?, decodedInstruction.rd),
                                value: fromMaybe(?, result)
                            };
                            executedInstruction.exception = tagged Invalid;
                        end
                    end
`endif

                    BRANCH: begin
                        dynamicAssert(isValid(decodedInstruction.rd) == False, "BRANCH: rd SHOULD BE invalid");
                        dynamicAssert(isValid(decodedInstruction.rs1), "BRANCH: rs1 is invalid");
                        dynamicAssert(isValid(decodedInstruction.rs2), "BRANCH: rs2 is invalid");
                        dynamicAssert(isValid(decodedInstruction.immediate), "BRANCH: immediate is invalid");

                        if (isValidBranchOperator(decodedInstruction.branchOperator) &&
                            isValid(decodedInstruction.immediate)) begin
                            Maybe#(ProgramCounter) nextProgramCounter = tagged Invalid;
                            if (isBranchTaken(decodedInstruction)) begin
                                // Determine branch target address and check
                                // for address misalignment.
                                let branchTarget = getEffectiveAddress(decodedInstruction.programCounter, unJust(decodedInstruction.immediate));
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
                                nextProgramCounter = tagged Valid (decodedInstruction.programCounter + 4);
                            end

                            if (nextProgramCounter matches tagged Valid .npc &&& npc != decodedInstruction.predictedNextProgramCounter) begin
                                executedInstruction.changedProgramCounter = tagged Valid npc;
                            end
                        end
                    end

                    COPY_IMMEDIATE: begin
                        dynamicAssert(isValid(decodedInstruction.rd), "COPY_IMMEDIATE: rd is invalid");
                        dynamicAssert(isValid(decodedInstruction.rs1) == False, "COPY_IMMEDIATE: rs1 SHOULD BE invalid");
                        dynamicAssert(isValid(decodedInstruction.rs2) == False, "COPY_IMMEDIATE: rs2 SHOULD BE invalid");
                        dynamicAssert(isValid(decodedInstruction.immediate), "COPY_IMMEDIATE: immediate is invalid");
                        executedInstruction.gprWriteBack = tagged Valid GPRWriteBack {
                            rd: fromMaybe(?, decodedInstruction.rd),
                            value: fromMaybe(?, decodedInstruction.immediate)
                        };
                        executedInstruction.exception = tagged Invalid;
                    end

                    CSR: begin
                        executedInstruction <- executeCSR(decodedInstruction, executedInstruction);
                    end

                    FENCE: begin
                        executedInstruction.exception = tagged Invalid;
                    end

                    JUMP: begin
                        dynamicAssert(isValid(decodedInstruction.rd), "JUMP: rd is invalid");
                        dynamicAssert(isValid(decodedInstruction.rs1) == False, "JUMP: rs1 SHOULD BE invalid");
                        dynamicAssert(isValid(decodedInstruction.rs2) == False, "JUMP: rs2 SHOULD BE invalid");
                        dynamicAssert(isValid(decodedInstruction.immediate), "JUMP: immediate is invalid");
  
                        let immediate = unJust(decodedInstruction.immediate);
                        let jumpTarget = getEffectiveAddress(decodedInstruction.programCounter, immediate);

                        if (verbose)
                            $display("JUMP: RS1: $%0x - Offset: $%0x - JumpTarget: $%0x", decodedInstruction.rs1Value, immediate, jumpTarget);

                        if (isValidInstructionAddress(jumpTarget) == False) begin
                            executedInstruction.exception = tagged Valid createMisalignedInstructionException(jumpTarget);
                        end else begin
                            executedInstruction.changedProgramCounter = tagged Valid jumpTarget;
                            executedInstruction.gprWriteBack = tagged Valid GPRWriteBack {
                                rd: fromMaybe(?, decodedInstruction.rd),
                                value: (decodedInstruction.programCounter + 4)
                            };
                            executedInstruction.exception = tagged Invalid;
                        end
                    end

                    JUMP_INDIRECT: begin
                        dynamicAssert(isValid(decodedInstruction.rd), "JUMP_INDIRECT: rd is invalid");
                        dynamicAssert(isValid(decodedInstruction.rs1), "JUMP_INDIRECT: rs1 is invalid");
                        dynamicAssert(isValid(decodedInstruction.rs2) == False, "JUMP_INDIRECT: rs2 SHOULD BE invalid");
                        dynamicAssert(isValid(decodedInstruction.immediate), "JUMP_INDIRECT: immediate is invalid");
                        
                        let immediate = unJust(decodedInstruction.immediate);
                        let jumpTarget = getEffectiveAddress(decodedInstruction.rs1Value, immediate);
                        jumpTarget[0] = 0;

                        if (verbose)
                            $display("JUMP_INDIRECT: RS1: $%0x - Offset: $%0x - JumpTarget: $%0x", decodedInstruction.rs1Value, immediate, jumpTarget);

                        if (isValidInstructionAddress(jumpTarget) == False) begin
                            executedInstruction.exception = tagged Valid createMisalignedInstructionException(jumpTarget);
                        end else begin
                            executedInstruction.changedProgramCounter = tagged Valid jumpTarget;
                            executedInstruction.gprWriteBack = tagged Valid GPRWriteBack {
                                rd: fromMaybe(?, decodedInstruction.rd),
                                value: (decodedInstruction.programCounter + 4)
                            };
                            executedInstruction.exception = tagged Invalid;
                        end
                    end

                    LOAD: begin
                        // The actual memory request is handled in the Memory Access stage.
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

                        if (verbose)
                            $display("LEA: $%0x - $%0x", effectiveAddress, decodedInstruction.loadOperator);
                        if (isSuccess(result)) begin
                            executedInstruction.loadRequest = tagged Valid result.Success;
                            executedInstruction.exception = tagged Invalid;
                        end else begin
                            executedInstruction.exception = tagged Valid result.Error;
                        end
                    end

                    STORE: begin
                        // The actual memory request is handled in the Memory Access stage.
                        dynamicAssert(isValid(decodedInstruction.rd) == False, "STORE: rd is valid");
                        dynamicAssert(isValid(decodedInstruction.rs1), "STORE: rs1 is invalid");
                        dynamicAssert(isValid(decodedInstruction.rs2), "STORE: rs2 is invalid");
                        dynamicAssert(isValid(decodedInstruction.immediate), "STORE: immediate is invalid");

                        let effectiveAddress = getEffectiveAddress(decodedInstruction.rs1Value, unJust(decodedInstruction.immediate));

                        if (verbose)
                            $display("Store effective address: $%x", effectiveAddress);

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
                    end

                    SYSTEM: begin
                        case(decodedInstruction.systemOperator)
                            sys_ECALL: begin
                                if (verbose)
                                    $display("%0d,%0d,%0d,%0x,%0d,execute,ECALL instruction encountered", decodedInstruction.fetchIndex, trapController.csrFile.cycle_counter, currentEpoch, decodedInstruction.programCounter, stageNumber);

                                let curPriv <- trapController.csrFile.getCurrentPrivilegeLevel.get;
                                executedInstruction.exception = tagged Valid createEnvironmentCallException(curPriv, decodedInstruction.programCounter);
                            end
                            sys_EBREAK: begin
                                if (verbose)
                                    $display("%0d,%0d,%0d,%0x,%0d,execute,EBREAK instruction encountered", decodedInstruction.fetchIndex, trapController.csrFile.cycle_counter, currentEpoch, decodedInstruction.programCounter, stageNumber);
                                executedInstruction.exception = tagged Valid createBreakpointException(decodedInstruction.programCounter);
                            end
                            sys_MRET: begin
                                if (verbose)
                                    $display("%0d,%0d,%0d,%0x,%0d,execute,MRET instruction", decodedInstruction.fetchIndex, trapController.csrFile.cycle_counter, currentEpoch, decodedInstruction.programCounter, stageNumber);
                                
                                let newProgramCounterReadStatus <- trapController.endTrap;
                                if (newProgramCounterReadStatus matches tagged Valid .newProgramCounter) begin
                                    executedInstruction.changedProgramCounter = tagged Valid newProgramCounter;
                                    executedInstruction.exception = tagged Invalid;
                                end else begin
                                    executedInstruction.exception = tagged Valid createIllegalInstructionException(decodedInstruction.programCounter);
                                end
                            end
                            default begin
                                executedInstruction.exception = tagged Invalid;
                            end
                        endcase
                    end
                endcase
            end

            return executedInstruction;
        endactionvalue
    endfunction

    interface Put putDecodedInstruction;
        method Action put(DecodedInstruction decodedInstruction);
            Bool verbose <- $test$plusargs ("verbose");
            let fetchIndex = decodedInstruction.fetchIndex;
            let stageEpoch = pipelineController.stageEpoch(stageNumber, 1);
            Maybe#(RVCSRIndex) scoreboardValue = tagged Invalid;

            if (!pipelineController.isCurrentEpoch(stageNumber, 1, decodedInstruction.pipelineEpoch)) begin
                if (verbose)
                    $display("%0d,%0d,%0d,%0x,%0d,execute,stale instruction (%0d != %0d)...adding bubble to pipeline", fetchIndex, trapController.csrFile.cycle_counter, decodedInstruction.pipelineEpoch, decodedInstruction.programCounter, stageNumber, decodedInstruction.pipelineEpoch, stageEpoch);
                outputQueue.enq(newExecutedInstructionFromDecodedInstruction(decodedInstruction));
            end else if (isValid(decodedInstruction.exception)) begin
                if (verbose)
                    $display("%0d,%0d,%0d,%0x,%0d,execute,EXCEPTION - decoded instruction had exception - propagating", fetchIndex, trapController.csrFile.cycle_counter, decodedInstruction.pipelineEpoch, decodedInstruction.programCounter, stageNumber);
                outputQueue.enq(newExecutedInstructionFromDecodedInstruction(decodedInstruction));
            end else begin
                let currentEpoch = stageEpoch;

                if (verbose) begin
                    $display("%0d,%0d,%0d,%0x,%0d,execute,executing instruction: ", fetchIndex, trapController.csrFile.cycle_counter, currentEpoch, decodedInstruction.programCounter, stageNumber, fshow(decodedInstruction.opcode));
                    $display("%0d,%0d,%0d,%0x,%0d,execute,RS1: ", fetchIndex, trapController.csrFile.cycle_counter, currentEpoch, decodedInstruction.programCounter, stageNumber, (isValid(decodedInstruction.rs1) ? $format("x%0d = %0d ($%0x)", unJust(decodedInstruction.rs1), decodedInstruction.rs1Value, decodedInstruction.rs1Value) : $format("INVALID")));
                    $display("%0d,%0d,%0d,%0x,%0d,execute,RS2: ", fetchIndex, trapController.csrFile.cycle_counter, currentEpoch, decodedInstruction.programCounter, stageNumber, (isValid(decodedInstruction.rs2) ? $format("x%0d = %0d ($%0x)", unJust(decodedInstruction.rs2), decodedInstruction.rs2Value, decodedInstruction.rs2Value) : $format("INVALID")));
                end

                let executedInstruction <- executeInstruction(decodedInstruction, currentEpoch);

                // If the program counter was changed, see if it matches a predicted branch/jump.
                // If not, redirect the program counter to the mispredicted target address.
                if (executedInstruction.changedProgramCounter matches tagged Valid .targetAddress &&& targetAddress != decodedInstruction.predictedNextProgramCounter) begin
                    // Bump the current instruction epoch
                    pipelineController.flush(1);

                    executedInstruction.pipelineEpoch = ~executedInstruction.pipelineEpoch;

                    if (verbose)
                        $display("%0d,%0d,%0d,%0x,%0d,execute,branch/jump to: $%08x", fetchIndex, cycleCounter, currentEpoch, decodedInstruction.programCounter, stageNumber, targetAddress);
                    programCounterRedirect.branch(targetAddress);
                end

                if (executedInstruction.exception matches tagged Valid .exception) begin
                    if (verbose) begin
                        $display("%0d,%0d,%0d,%0x,%0d,execute,EXCEPTION:", fetchIndex, cycleCounter, currentEpoch, decodedInstruction.programCounter, stageNumber, fshow(exception));
                    end
                end

                // If writeback data exists, that needs to be written into the previous pipeline 
                // stages using operand forwarding.
                if (executedInstruction.gprWriteBack matches tagged Valid .wb) begin
                    gprBypassValue.wset(tagged Valid GPRBypassValue {
                        rd: wb.rd,
                        value: tagged Valid wb.value
                    });
                    if (verbose) begin
                        $display("%0d,%0d,%0d,%0x,%0d,execute, (GPR WB: x%0d = %08x)", fetchIndex, cycleCounter, currentEpoch, decodedInstruction.programCounter, stageNumber, wb.rd, wb.value);
                    end
                end

                if (executedInstruction.csrWriteBack matches tagged Valid .wb) begin
                    if (verbose) begin
                        $display("%0d,%0d,%0d,%0x,%0d,execute, (CSR WB: $%0x = $%08x)", fetchIndex, cycleCounter, currentEpoch, decodedInstruction.programCounter, stageNumber, wb.rd, wb.value);
                    end
                end

                if (verbose)
                    $display("%0d,%0d,%0d,%0x,%0d,execute,complete", fetchIndex, cycleCounter, currentEpoch, decodedInstruction.programCounter, stageNumber);

                scoreboardValue = decodedInstruction.csrIndex;

                outputQueue.enq(executedInstruction);
            end

            scoreboard.insert(scoreboardValue);
        endmethod
    endinterface

    interface Put putCycleCounter = toPut(asIfc(cycleCounter));
    interface Get getExecutedInstruction = toGet(outputQueue);
    interface Get getGPRBypassValue = toGet(gprBypassValue);
    interface Put putHalt = toPut(asIfc(halt));
endmodule
