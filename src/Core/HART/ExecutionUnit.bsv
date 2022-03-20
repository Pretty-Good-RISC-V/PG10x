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
import ExceptionController::*;
import ExecutedInstruction::*;
import LoadStore::*;
import PipelineController::*;
import ProgramCounterRedirect::*;

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

`ifdef ENABLE_RISCOF_TESTS
RVCSRIndex csr_RISCOF_HALT = 12'h7C0;      // Register, that when written, is used to halt a RISCOF test (and the simulation).
`endif

module mkExecutionUnit#(
    Integer stageNumber,
    PipelineController pipelineController,
    ProgramCounterRedirect programCounterRedirect,
    ExceptionController exceptionController
)(ExecutionUnit);
    Wire#(Word64) cycleCounter <- mkBypassWire;
    FIFO#(ExecutedInstruction) outputQueue <- mkPipelineFIFO;
    RWire#(Maybe#(GPRBypassValue)) gprBypassValue <- mkRWire();
    Reg#(Bool) halt <- mkReg(False);

    ALU alu <- mkALU;

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

            let operand = fromMaybe(decodedInstruction.rs1Value, decodedInstruction.immediate);
            let csrIndex = decodedInstruction.csrIndex;
            let csrWriteEnabled = (isValid(decodedInstruction.immediate) || unJust(decodedInstruction.rs1) != 0);
            let rd = unJust(decodedInstruction.rd);

            let immediateIsZero = (isValid(decodedInstruction.immediate) ? unJust(decodedInstruction.immediate) == 0 : False);

            let readStatus = exceptionController.csrFile.read2(csrIndex);
            if (readStatus matches tagged Valid .currentValue) begin
                executedInstruction.writeBack = tagged Valid WriteBack {
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
`ifdef ENABLE_RISCOF_TESTS
                    // Special case handling for tests
                    if (csrIndex == csr_RISCOF_HALT) begin
                        $display("CSR($%0x): RISCOF Test Halt Requested", csrIndex);
                        executedInstruction.exception = tagged Valid createRISCOFTestHaltException(decodedInstruction.programCounter);
                    end else 
`endif
                    begin
                        let writeSucceeded <- exceptionController.csrFile.write2(csrIndex, v);
                        if (writeSucceeded == False) begin
                            $display("CSR($%0x): Write failed", csrIndex);
                            executedInstruction.exception = tagged Valid createIllegalInstructionException(decodedInstruction.rawInstruction);
                        end else begin
                            executedInstruction.exception = tagged Invalid;
                        end
                    end
                end else begin
                    $display("CSR($%0x): Write not requested", csrIndex);
                    executedInstruction.exception = tagged Invalid;
                end
            end else begin
                executedInstruction.exception = tagged Valid createIllegalInstructionException(decodedInstruction.rawInstruction);
                $display("CSR($%0x): Read failed", decodedInstruction.csrIndex);
            end
        end
        return executedInstruction;
        endactionvalue
    endfunction

    function ActionValue#(ExecutedInstruction) executeInstruction(
        DecodedInstruction decodedInstruction,
        PipelineEpoch currentEpoch);
        actionvalue
            let executedInstruction = ExecutedInstruction {
                fetchIndex: decodedInstruction.fetchIndex,
                pipelineEpoch: decodedInstruction.pipelineEpoch,
                programCounter: decodedInstruction.programCounter,
                rawInstruction: decodedInstruction.rawInstruction,
                changedProgramCounter: tagged Invalid,
                loadRequest: tagged Invalid,
                storeRequest: tagged Invalid,
                exception: tagged Valid createIllegalInstructionException(decodedInstruction.rawInstruction),
                writeBack: tagged Invalid
            };

            // Check for an existing pending interrupt.
            let pendingInterrupt = False;
            let highestPriorityInterrupt <- exceptionController.getHighestPriorityInterrupt(True, 1);
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
                            executedInstruction.writeBack = tagged Valid WriteBack {
                                rd: fromMaybe(?, decodedInstruction.rd),
                                value: fromMaybe(?, result)
                            };
                            executedInstruction.exception = tagged Invalid;
                        end
                    end

`ifdef RV64
                    ALU3264: begin
                        dynamicAssert(isValid(decodedInstruction.rd), "ALU: rd is invalid");
                        dynamicAssert(isValid(decodedInstruction.rs1), "ALU: rs1 is invalid");

                        let result = alu.execute3264(
                            decodedInstruction.aluOperator, 
                            decodedInstruction.rs1Value,
                            fromMaybe(decodedInstruction.rs2Value, decodedInstruction.immediate)
                        );

                        if (isValid(result)) begin
                            executedInstruction.writeBack = tagged Valid WriteBack {
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
                        executedInstruction.writeBack = tagged Valid WriteBack {
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

                        $display("JUMP: RS1: $%0x - Offset: $%0x - JumpTarget: $%0x", decodedInstruction.rs1Value, immediate, jumpTarget);

                        if (isValidInstructionAddress(jumpTarget) == False) begin
                            executedInstruction.exception = tagged Valid createMisalignedInstructionException(jumpTarget);
                        end else begin
                            executedInstruction.changedProgramCounter = tagged Valid jumpTarget;
                            executedInstruction.writeBack = tagged Valid WriteBack {
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

                        $display("JUMP_INDIRECT: RS1: $%0x - Offset: $%0x - JumpTarget: $%0x", decodedInstruction.rs1Value, immediate, jumpTarget);

                        if (isValidInstructionAddress(jumpTarget) == False) begin
                            executedInstruction.exception = tagged Valid createMisalignedInstructionException(jumpTarget);
                        end else begin
                            executedInstruction.changedProgramCounter = tagged Valid jumpTarget;
                            executedInstruction.writeBack = tagged Valid WriteBack {
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
                                $display("%0d,%0d,%0d,%0x,%0d,execute,ECALL instruction encountered", decodedInstruction.fetchIndex, exceptionController.csrFile.cycle_counter, currentEpoch, decodedInstruction.programCounter, stageNumber);
                                executedInstruction.exception = tagged Valid createEnvironmentCallException(decodedInstruction.programCounter);
                            end
                            sys_EBREAK: begin
                                $display("%0d,%0d,%0d,%0x,%0d,execute,EBREAK instruction encountered", decodedInstruction.fetchIndex, exceptionController.csrFile.cycle_counter, currentEpoch, decodedInstruction.programCounter, stageNumber);
                                executedInstruction.exception = tagged Valid createBreakpointException(decodedInstruction.programCounter);
                            end
                            sys_MRET: begin
                                $display("%0d,%0d,%0d,%0x,%0d,execute,MRET instruction", decodedInstruction.fetchIndex, exceptionController.csrFile.cycle_counter, currentEpoch, decodedInstruction.programCounter, stageNumber);
                                let readStatus = exceptionController.csrFile.read2(csr_MEPC);
                                if (readStatus matches tagged Valid .mepc) begin
                                    executedInstruction.changedProgramCounter = tagged Valid mepc;
                                    executedInstruction.exception = tagged Invalid;
                                end else begin
                                    $display("%0d,%0d,%0d,%0x,%0d,execute,MRET instruction - failed to read MEPC", decodedInstruction.fetchIndex, exceptionController.csrFile.cycle_counter, currentEpoch, decodedInstruction.programCounter, stageNumber);
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
            let fetchIndex = decodedInstruction.fetchIndex;
            let stageEpoch = pipelineController.stageEpoch(stageNumber, 1);

            if (!pipelineController.isCurrentEpoch(stageNumber, 1, decodedInstruction.pipelineEpoch)) begin
                $display("%0d,%0d,%0d,%0x,%0d,execute,stale instruction (%0d != %0d)...adding bubble to pipeline", fetchIndex, exceptionController.csrFile.cycle_counter, decodedInstruction.pipelineEpoch, decodedInstruction.programCounter, stageNumber, decodedInstruction.pipelineEpoch, stageEpoch);
                outputQueue.enq(ExecutedInstruction{
                    fetchIndex: decodedInstruction.fetchIndex,
                    pipelineEpoch: decodedInstruction.pipelineEpoch,
                    programCounter: decodedInstruction.programCounter,
                    rawInstruction: decodedInstruction.rawInstruction,
                    changedProgramCounter: tagged Invalid,
                    loadRequest: tagged Invalid,
                    storeRequest: tagged Invalid,
                    exception: tagged Invalid,
                    writeBack: tagged Invalid
                });
            end else if (isValid(decodedInstruction.exception)) begin
                $display("%0d,%0d,%0d,%0x,%0d,execute,EXCEPTION - decoded instruction had exception - prooagating", fetchIndex, exceptionController.csrFile.cycle_counter, decodedInstruction.pipelineEpoch, decodedInstruction.programCounter, stageNumber, decodedInstruction.pipelineEpoch, stageEpoch);
                outputQueue.enq(ExecutedInstruction{
                    fetchIndex: decodedInstruction.fetchIndex,
                    pipelineEpoch: decodedInstruction.pipelineEpoch,
                    programCounter: decodedInstruction.programCounter,
                    rawInstruction: decodedInstruction.rawInstruction,
                    changedProgramCounter: tagged Invalid,
                    loadRequest: tagged Invalid,
                    storeRequest: tagged Invalid,
                    exception: decodedInstruction.exception,
                    writeBack: tagged Invalid
                });
            end else begin
                let currentEpoch = stageEpoch;

                $display("%0d,%0d,%0d,%0x,%0d,execute,executing instruction: ", fetchIndex, exceptionController.csrFile.cycle_counter, currentEpoch, decodedInstruction.programCounter, stageNumber, fshow(decodedInstruction.opcode));
                $display("%0d,%0d,%0d,%0x,%0d,execute,RS1: ", fetchIndex, exceptionController.csrFile.cycle_counter, currentEpoch, decodedInstruction.programCounter, stageNumber, (isValid(decodedInstruction.rs1) ? $format("x%0d = %0d ($%0x)", unJust(decodedInstruction.rs1), decodedInstruction.rs1Value, decodedInstruction.rs1Value) : $format("INVALID")));
                $display("%0d,%0d,%0d,%0x,%0d,execute,RS2: ", fetchIndex, exceptionController.csrFile.cycle_counter, currentEpoch, decodedInstruction.programCounter, stageNumber, (isValid(decodedInstruction.rs2) ? $format("x%0d = %0d ($%0x)", unJust(decodedInstruction.rs2), decodedInstruction.rs2Value, decodedInstruction.rs2Value) : $format("INVALID")));
                
                let executedInstruction <- executeInstruction(decodedInstruction, currentEpoch);

                // If the program counter was changed, see if it matches a predicted branch/jump.
                // If not, redirect the program counter to the mispredicted target address.
                if (executedInstruction.changedProgramCounter matches tagged Valid .targetAddress &&& targetAddress != decodedInstruction.predictedNextProgramCounter) begin
                    // Bump the current instruction epoch
                    pipelineController.flush(1);

                    executedInstruction.pipelineEpoch = ~executedInstruction.pipelineEpoch;

                    $display("%0d,%0d,%0d,%0x,%0d,execute,branch/jump to: $%08x", fetchIndex, cycleCounter, currentEpoch, decodedInstruction.programCounter, stageNumber, targetAddress);
                    programCounterRedirect.branch(targetAddress);
                end

                if (executedInstruction.exception matches tagged Valid .exception) begin
                    $display("%0d,%0d,%0d,%0x,%0d,execute,EXCEPTION:", fetchIndex, cycleCounter, currentEpoch, decodedInstruction.programCounter, stageNumber, fshow(exception));
                end

                // If writeback data exists, that needs to be written into the previous pipeline 
                // stages using operand forwarding.
                if (executedInstruction.writeBack matches tagged Valid .wb) begin
                    gprBypassValue.wset(tagged Valid GPRBypassValue {
                        rd: wb.rd,
                        value: tagged Valid wb.value
                    });
                    $display("%0d,%0d,%0d,%0x,%0d,execute,complete (WB: x%0d = %08x)", fetchIndex, cycleCounter, currentEpoch, decodedInstruction.programCounter, stageNumber, wb.rd, wb.value);
                end else begin
                    $display("%0d,%0d,%0d,%0x,%0d,execute,complete", fetchIndex, cycleCounter, currentEpoch, decodedInstruction.programCounter, stageNumber);
                end

                outputQueue.enq(executedInstruction);
            end
        endmethod
    endinterface

    interface Put putCycleCounter = toPut(asIfc(cycleCounter));
    interface Get getExecutedInstruction = toGet(outputQueue);
    interface Get getGPRBypassValue = toGet(gprBypassValue);
    interface Put putHalt = toPut(asIfc(halt));
endmodule
