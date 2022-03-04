//
// MemoryAccessUnit
//
// This module is responsible for handling RISC-V LOAD and STORE instructions.  It 
// accepts a 'ExecutedInstruction' structure and if the values contained therein have
// valid LoadRequest or StoreRequest structures, the requisite load and store operations
// are executed.
//
import PGTypes::*;

import EncodedInstruction::*;
import ExecutedInstruction::*;
import LoadStore::*;
import MemoryInterfaces::*;
import PipelineController::*;

import Assert::*;
import FIFO::*;
import SpecialFIFOs::*;

export MemoryAccessUnit(..), mkMemoryAccessUnit;

interface MemoryAccessUnit;
    interface FIFO#(ExecutedInstruction) getMemoryAccessedInstructionQueue;
endinterface

module mkMemoryAccessUnit#(
    Reg#(Word64) cycleCounter,
    Integer stageNumber,
    PipelineController pipelineController,
    FIFO#(ExecutedInstruction) inputQueue,
`ifdef MONITOR_TOHOST_ADDRESS
    TileLinkLiteWordServer dataMemory,
    Word toHostAddress
`else
    TileLinkLiteWordServer dataMemory
`endif
)(MemoryAccessUnit);
    FIFO#(ExecutedInstruction) outputQueue <- mkPipelineFIFO;
    Reg#(Bool) waitingForLoadToComplete <- mkReg(False);
    Reg#(Bool) waitingForStoreResponse <- mkReg(False);

    Reg#(ExecutedInstruction) instructionWaitingForMemoryOperation <- mkRegU;

    (* fire_when_enabled *)
    rule memoryAccess(waitingForLoadToComplete == False && waitingForStoreResponse == False);
        let executedInstruction = inputQueue.first;
        let fetchIndex = executedInstruction.fetchIndex;
        let stageEpoch = pipelineController.stageEpoch(stageNumber, 1);
        if (!pipelineController.isCurrentEpoch(stageNumber, 1, executedInstruction.pipelineEpoch)) begin
            $display("%0d,%0d,%0d,%0d,memory access,stale instruction (%0d != %0d)...propagating bubble", fetchIndex, cycleCounter, executedInstruction.pipelineEpoch, inputQueue.first().programCounter, stageNumber, inputQueue.first().pipelineEpoch, stageEpoch);
            inputQueue.deq;
            outputQueue.enq(executedInstruction);
        end else begin
            if(executedInstruction.loadRequest matches tagged Valid .loadRequest) begin
                $display("%0d,%0d,%0d,%0x,%0d,memory access,LOAD", fetchIndex, cycleCounter, stageEpoch, executedInstruction.programCounter, stageNumber);
                begin
                    // NOTE: Alignment checks were already performed during the execution stage.
                    dataMemory.request.put(loadRequest.tlRequest);

                    $display("%0d,%0d,%0d,%0x,%0d,memory access,Loading from $%08x", fetchIndex, cycleCounter, executedInstruction.programCounter, loadRequest.tlRequest.a_address);
                    instructionWaitingForMemoryOperation <= executedInstruction;
                    waitingForLoadToComplete <= True;
                end
            end else if (executedInstruction.storeRequest matches tagged Valid .storeRequest) begin
                $display("%0d,%0d,%0d,%0x,%0d,memory access,Storing to $0x", fetchIndex, cycleCounter, stageEpoch, executedInstruction.programCounter, storeRequest.tlRequest.a_address);
`ifdef MONITOR_TOHOST_ADDRESS
                if (storeRequest.tlRequest.a_address == toHostAddress) begin
                    let test_num = (storeRequest.tlRequest.a_data >> 1);
                    if (test_num == 0) $display ("    PASS");
                    else               $display ("    FAIL <test_%0d>", test_num);

                    $finish();
                end
`endif
                dataMemory.request.put(storeRequest.tlRequest);
                waitingForStoreResponse <= True;
            end else begin
                // Not a LOAD/STORE
                $display("%0d,%0d,%0d,%0x,%0d,memory access,NO-OP", fetchIndex, cycleCounter, stageEpoch, executedInstruction.programCounter, stageNumber);

                inputQueue.deq;
                outputQueue.enq(executedInstruction);
            end
        end
    endrule

    rule handleStoreResponse(waitingForStoreResponse == True && waitingForLoadToComplete == False);
        let memoryResponse <- dataMemory.response.get;
        let executedInstruction = instructionWaitingForMemoryOperation;

        waitingForStoreResponse <= False;

        if (memoryResponse.d_opcode != d_ACCESS_ACK) begin
            $display("[%0d:****:memory] FATAL - Store returned unexpected opcode: ", fshow(memoryResponse));
            $fatal();
        end

        if (memoryResponse.d_denied) begin
            $display("[%0d:****:memory] FATAL - Store returned access denied: ", fshow(memoryResponse));
            $fatal();
        end

        if (memoryResponse.d_corrupt) begin
            $display("[%0d:****:memory] FATAL - Store returned access corrupted: ", fshow(memoryResponse));
            $fatal();
        end

        inputQueue.deq;
        outputQueue.enq(executedInstruction);
    endrule

    rule handleLoadResponse(waitingForLoadToComplete == True && waitingForStoreResponse == False);
        let memoryResponse <- dataMemory.response.get;
        let executedInstruction = instructionWaitingForMemoryOperation;

        $display("[%0d:****:memory] Load completed", cycleCounter, executedInstruction.programCounter);

        waitingForLoadToComplete <= False;

        if (memoryResponse.d_opcode != d_ACCESS_ACK_DATA) begin
            $display("[%0d:****:memory] FATAL - Load returned unexpected opcode: ", fshow(memoryResponse));
            $fatal();
        end

        if (memoryResponse.d_denied) begin
            $display("[%0d:****:memory] FATAL - Load returned access denied: ", fshow(memoryResponse));
            $fatal();
        end

        if (memoryResponse.d_corrupt) begin
            $display("[%0d:****:memory] FATAL - Load returned access corrupted: ", fshow(memoryResponse));
            $fatal();
        end

        // Save the data that will be written back into the register file on the
        // writeback pipeline stage.
        let loadRequest = unJust(executedInstruction.loadRequest);
        Word value = ?;
        case (loadRequest.tlRequest.a_size)
            0: begin    // 1 byte
                if (loadRequest.signExtend)
                    value = signExtend(memoryResponse.d_data[7:0]);
                else
                    value = zeroExtend(memoryResponse.d_data[7:0]);
            end
            1: begin    // 2 bytes
                if (loadRequest.signExtend)
                    value = signExtend(memoryResponse.d_data[15:0]);
                else
                    value = zeroExtend(memoryResponse.d_data[15:0]);
            end
`ifdef RV32
            2: begin    // 4 bytes
                value = memoryResponse.d_data;
            end
`elsif RV64
            2: begin    // 4 bytes
                if (loadRequest.signExtend)
                    value = signExtend(memoryResponse.d_data[31:0]);
                else
                    value = zeroExtend(memoryResponse.d_data[31:0]);
            end
            3: begin    // 8 bytes
                value = memoryResponse.d_data;
            end
`endif
        endcase
        executedInstruction.writeBack = tagged Valid WriteBack {
            rd: loadRequest.rd,
            value: value
        };

        inputQueue.deq;
        outputQueue.enq(executedInstruction);
    endrule

    interface FIFO getMemoryAccessedInstructionQueue = outputQueue;
endmodule
