//
// ExecutionUnit
//
// This module is a RISC-V instruction execution unit.  It is responsible for executing instructions 
// described by a 'DecodedInstruction' structure resulting in a 'ExecutedInstruction' structure. 
//
`include "PGLib.bsh"

import ALU::*;
import CSRFile::*;
import DecodedInstruction::*;
import Exception::*;
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
    interface FIFO#(ExecutedInstruction) getExecutedInstructionQueue;
endinterface

module mkExecutionUnit#(
    Reg#(Word64) cycleCounter,
    Integer stageNumber,
    PipelineController pipelineController,
    FIFO#(DecodedInstruction) inputQueue,
    ProgramCounterRedirect programCounterRedirect,
    Reg#(RVPrivilegeLevel) currentPrivilegeLevel,
    CSRFile csrFile,
    Reg#(Bool) halt
)(ExecutionUnit);
    FIFO#(ExecutedInstruction) outputQueue <- mkPipelineFIFO();

    ALU alu <- mkALU();

    function Bool isValidBranchOperator(RVBranchOperator operator);
        return (operator != pack(UNSUPPORTED_BRANCH_OPERATOR_010) &&
                operator != pack(UNSUPPORTED_BRANCH_OPERATOR_011)) ? True : False;
    endfunction

    function Bool isBranchTaken(DecodedInstruction decodedInstruction);
        // NOTE: Validity of the branch operator has already been checked.
        return case(decodedInstruction.branchOperator)
            pack(BEQ): return (decodedInstruction.rs1Value == decodedInstruction.rs2Value);
            pack(BNE): return (decodedInstruction.rs1Value != decodedInstruction.rs2Value);
            pack(BLT): return (signedLT(decodedInstruction.rs1Value, decodedInstruction.rs2Value));
            pack(BGE): return (signedGE(decodedInstruction.rs1Value, decodedInstruction.rs2Value));
            pack(BGEU): return (decodedInstruction.rs1Value >= decodedInstruction.rs2Value);
            pack(BLTU): return (decodedInstruction.rs1Value < decodedInstruction.rs2Value);
        endcase;
    endfunction

    function ActionValue#(ExecutedInstruction) executeCSR(
        DecodedInstruction decodedInstruction,
        CSRFile csrFile,
        ExecutedInstruction executedInstruction
    );
        actionvalue
        if (decodedInstruction.csrOperator[1:0] != 0) begin
            dynamicAssert(isValid(decodedInstruction.rd), "RD is invalid");

            let operand = (isValid(decodedInstruction.immediate) ? 
                unJust(decodedInstruction.immediate) : decodedInstruction.rs1Value);
            let csrIndex = decodedInstruction.csrIndex;
            let csrWriteEnabled = (isValid(decodedInstruction.immediate) || unJust(decodedInstruction.rs1) != 0);
            let rd = unJust(decodedInstruction.rd);

            let immediateIsZero = (isValid(decodedInstruction.immediate) ? unJust(decodedInstruction.immediate) == 0 : False);

            let readStatus = csrFile.read1(currentPrivilegeLevel, csrIndex);
            if (isValid(readStatus)) begin
                let currentValue = unJust(readStatus);

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
                    let writeSucceeded <- csrFile.write1(currentPrivilegeLevel, csrIndex, v);
                    if (writeSucceeded == False) begin
                        $display("CSR($%0x): Write failed", csrIndex);
                        executedInstruction.exception = tagged Valid tagged ExceptionCause extend(pack(ILLEGAL_INSTRUCTION));
                    end else begin
                        executedInstruction.exception = tagged Invalid;
                    end
                end else begin
                    $display("CSR($%0x): Write not requested", csrIndex);
                    executedInstruction.exception = tagged Invalid;
                end
            end else begin
                executedInstruction.exception = tagged Valid tagged ExceptionCause extend(pack(ILLEGAL_INSTRUCTION));
                $display("CSR($%0x): Read failed", decodedInstruction.csrIndex);
            end
        end
        return executedInstruction;
        endactionvalue
    endfunction

    function ActionValue#(ExecutedInstruction) executeInstruction(
        DecodedInstruction decodedInstruction,
        CSRFile csrFile,
        PipelineEpoch currentEpoch);
        actionvalue
            let executedInstruction = ExecutedInstruction {
                fetchIndex: decodedInstruction.fetchIndex,
                pipelineEpoch: decodedInstruction.pipelineEpoch,
                programCounter: decodedInstruction.programCounter,
`ifdef ENABLE_INSTRUCTION_LOGGING
                rawInstruction: decodedInstruction.rawInstruction,
`endif
                changedProgramCounter: tagged Invalid,
                loadRequest: tagged Invalid,
                storeRequest: tagged Invalid,
                exception: tagged Valid tagged ExceptionCause extend(pack(ILLEGAL_INSTRUCTION)),
                writeBack: tagged Invalid
            };

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

                BRANCH: begin
                    dynamicAssert(isValid(decodedInstruction.rd) == False, "BRANCH: rd SHOULD BE invalid");
                    dynamicAssert(isValid(decodedInstruction.rs1), "BRANCH: rs1 is invalid");
                    dynamicAssert(isValid(decodedInstruction.rs2), "BRANCH: rs2 is invalid");
                    dynamicAssert(isValid(decodedInstruction.immediate), "BRANCH: immediate is invalid");

                    if (isValidBranchOperator(decodedInstruction.branchOperator) &&
                        isValid(decodedInstruction.immediate)) begin
                        let nextProgramCounter = ?;
                        if (isBranchTaken(decodedInstruction)) begin
                            // Determine branch target address and check
                            // for address misalignment.
                            let branchTarget = getEffectiveAddress(decodedInstruction.programCounter, unJust(decodedInstruction.immediate));
                            // Branch target must be 32 bit aligned.
                            if (branchTarget[1:0] != 0) begin
                                executedInstruction.exception = tagged Valid tagged ExceptionCause extend(pack(INSTRUCTION_ADDRESS_MISALIGNED));
                            end else begin
                                // Target address aligned
                                executedInstruction.exception = tagged Invalid;
                                nextProgramCounter = branchTarget;
                            end
                        end else begin
                            executedInstruction.exception = tagged Invalid;
                            nextProgramCounter = decodedInstruction.programCounter + 4;
                        end

                        if (nextProgramCounter != decodedInstruction.predictedNextProgramCounter) begin
                            executedInstruction.changedProgramCounter = tagged Valid nextProgramCounter;
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
                    executedInstruction <- executeCSR(decodedInstruction, csrFile, executedInstruction);
                end

                FENCE: begin
                    executedInstruction.exception = tagged Invalid;
                end

                JUMP: begin
                    dynamicAssert(isValid(decodedInstruction.rd), "JUMP: rd is invalid");
                    dynamicAssert(isValid(decodedInstruction.rs1) == False, "JUMP: rs1 SHOULD BE invalid");
                    dynamicAssert(isValid(decodedInstruction.rs2) == False, "JUMP: rs2 SHOULD BE invalid");
                    dynamicAssert(isValid(decodedInstruction.immediate), "JUMP: immediate is invalid");
                    
                    let jumpTarget = getEffectiveAddress(decodedInstruction.programCounter, unJust(decodedInstruction.immediate));
                    if (jumpTarget[1:0] != 0) begin
                        executedInstruction.exception = tagged Valid tagged ExceptionCause extend(pack(INSTRUCTION_ADDRESS_MISALIGNED));
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
                    
                    let jumpTarget = getEffectiveAddress(decodedInstruction.rs1Value, unJust(decodedInstruction.immediate));
                    jumpTarget[0] = 0;

                    if (jumpTarget[1:0] != 0) begin
                        executedInstruction.exception = tagged Valid tagged ExceptionCause extend(pack(INSTRUCTION_ADDRESS_MISALIGNED));
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
                        decodedInstruction.storeOperator,
                        rd,
                        effectiveAddress
                    );

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
                        pack(ECALL): begin
                            $display("%0d,%0d,%0d,%0x,%0d,execute,ECALL instruction encountered", decodedInstruction.fetchIndex, csrFile.cycle_counter, currentEpoch, decodedInstruction.programCounter, stageNumber);
                            executedInstruction.exception = tagged Valid tagged ExceptionCause extend(pack(ENVIRONMENT_CALL_FROM_M_MODE));
                        end
                        pack(MRET): begin
                            $display("%0d,%0d,%0d,%0x,%0d,execute,MRET instruction", decodedInstruction.fetchIndex, csrFile.cycle_counter, currentEpoch, decodedInstruction.programCounter, stageNumber);
                            let readStatus = csrFile.read1(currentPrivilegeLevel, pack(MEPC));
                            if (readStatus matches tagged Valid .mepc) begin
                                executedInstruction.changedProgramCounter = tagged Valid mepc;
                                executedInstruction.exception = tagged Invalid;
                            end else begin
                                $display("%0d,%0d,%0d,%0x,%0d,execute,MRET instruction - failed to read MEPC");
                            end
                        end
                        default begin
                            executedInstruction.exception = tagged Invalid;
                        end
                    endcase
                end
            endcase

            return executedInstruction;
        endactionvalue
    endfunction

    (* fire_when_enabled *)
    rule execute;
        let decodedInstruction = inputQueue.first();
        inputQueue.deq();

        let fetchIndex = decodedInstruction.fetchIndex;
        let stageEpoch = pipelineController.stageEpoch(stageNumber, 1);

        if (!pipelineController.isCurrentEpoch(stageNumber, 1, decodedInstruction.pipelineEpoch)) begin
            $display("%0d,%0d,%0d,%0x,%0d,execute,stale instruction (%0d != %0d)...ignoring", fetchIndex, csrFile.cycle_counter, decodedInstruction.pipelineEpoch, inputQueue.first().programCounter, stageNumber, inputQueue.first().pipelineEpoch, stageEpoch);
        end else begin
            let currentEpoch = stageEpoch;

            $display("%0d,%0d,%0d,%0x,%0d,execute,executing instruction: ", fetchIndex, csrFile.cycle_counter, currentEpoch, decodedInstruction.programCounter, stageNumber, fshow(decodedInstruction.opcode));
            $display("%0d,%0d,%0d,%0x,%0d,execute,RS1: ", fetchIndex, csrFile.cycle_counter, currentEpoch, decodedInstruction.programCounter, stageNumber, (isValid(decodedInstruction.rs1) ? $format("x%0d = %0d ($%0x)", unJust(decodedInstruction.rs1), decodedInstruction.rs1Value, decodedInstruction.rs1Value) : $format("INVALID")));
            $display("%0d,%0d,%0d,%0x,%0d,execute,RS2: ", fetchIndex, csrFile.cycle_counter, currentEpoch, decodedInstruction.programCounter, stageNumber, (isValid(decodedInstruction.rs2) ? $format("x%0d = %0d ($%0x)", unJust(decodedInstruction.rs2), decodedInstruction.rs2Value, decodedInstruction.rs2Value) : $format("INVALID")));
            
            let executedInstruction <- executeInstruction(decodedInstruction, csrFile, currentEpoch);
            if (executedInstruction.exception matches tagged Valid .exception) begin
                $display("%0d,%0d,%0d,%0x,%0d,execute,EXCEPTION:", fetchIndex, cycleCounter, currentEpoch, decodedInstruction.programCounter, stageNumber, fshow(exception));
            end

            // If the program counter was changed, see if it matches a predicted branch/jump.
            // If not, redirect the program counter to the mispredicted target address.
            if (isValid(executedInstruction.changedProgramCounter)) begin
                let targetAddress = unJust(executedInstruction.changedProgramCounter);
                if (decodedInstruction.predictedNextProgramCounter != targetAddress) begin
                    pipelineController.flush(1);

                    // Bump the current instruction epoch
                    executedInstruction.pipelineEpoch = ~executedInstruction.pipelineEpoch;

                    $display("%0d,%0d,%0d,%0x,%0d,execute,branch/jump to: $%08x", fetchIndex, cycleCounter, currentEpoch, decodedInstruction.programCounter, stageNumber, targetAddress);
                    programCounterRedirect.branch(targetAddress);
                end
            end

            // If writeback data exists, that needs to be written into the previous pipeline 
            // stages using operand forwarding.
            if (executedInstruction.writeBack matches tagged Valid .wb) begin
                $display("%0d,%0d,%0d,%0x,%0d,execute,complete (WB: x%0d = %08x)", fetchIndex, cycleCounter, currentEpoch, decodedInstruction.programCounter, stageNumber, wb.rd, wb.value);
            end else begin
                $display("%0d,%0d,%0d,%0x,%0d,execute,complete", fetchIndex, cycleCounter, currentEpoch, decodedInstruction.programCounter, stageNumber);
            end

            outputQueue.enq(executedInstruction);
        end
    endrule

    interface FIFO getExecutedInstructionQueue = outputQueue;
endmodule
