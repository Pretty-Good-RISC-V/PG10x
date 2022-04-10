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
import Exception::*;
import ExecutedInstruction::*;
import LoadStore::*;
import PipelineController::*;
import TileLink::*;

import Assert::*;
import ClientServer::*;
import FIFO::*;
import GetPut::*;
import SpecialFIFOs::*;

export MemoryAccessUnit(..), mkMemoryAccessUnit, MemoryAccess(..);

typedef struct {
    VirtualAddress address;
    Word value;
    Bool isStore;
} MemoryAccess deriving(Bits, Eq, FShow);

interface MemoryAccessUnit;
    interface Put#(Word64) putCycleCounter;

    interface Put#(ExecutedInstruction) putExecutedInstruction;
    interface Get#(ExecutedInstruction) getExecutedInstruction;

    interface StdTileLinkClient dataMemoryClient;

    interface Get#(Word) getLoadResult;
    interface Get#(Maybe#(MemoryAccess)) getMemoryAccess;
endinterface

module mkMemoryAccessUnit#(
    Integer stageNumber,
    PipelineController pipelineController
)(MemoryAccessUnit);
    Wire#(Word64) cycleCounter <- mkBypassWire;
    FIFO#(ExecutedInstruction) outputQueue <- mkPipelineFIFO;
    RWire#(MemoryAccess) memoryAccess <- mkRWire;

    Reg#(Bool) waitingForMemoryResponse <- mkReg(False);

    Reg#(ExecutedInstruction) instructionWaitingForMemoryOperation <- mkRegU;
    FIFO#(StdTileLinkRequest) dataMemoryRequests <- mkFIFO;
    FIFO#(StdTileLinkResponse) dataMemoryResponses <- mkFIFO;

    RWire#(Word) loadResult <- mkRWire();

    rule handleMemoryResponse(waitingForMemoryResponse == True);
        Bool verbose <- $test$plusargs ("verbose");
        let memoryResponse <- pop(dataMemoryResponses);
        let executedInstruction = instructionWaitingForMemoryOperation;
        waitingForMemoryResponse <= False;

        if (executedInstruction.storeRequest matches tagged Valid .storeRequest) begin
            let storeAddress = storeRequest.tlRequest.a_address;
            if (memoryResponse.d_denied) begin
                if (verbose)
                    $display("[****:****:memory] ERROR - Store returned access denied: ", fshow(memoryResponse));
                executedInstruction.exception = tagged Valid createStoreAccessFaultException(storeAddress);
            end else
            if (memoryResponse.d_corrupt) begin
                if (verbose)
                     $display("[****:****:memory] ERROR - Store returned access corrupted: ", fshow(memoryResponse));
                executedInstruction.exception = tagged Valid createStoreAccessFaultException(storeAddress);
            end else
            if (memoryResponse.d_opcode != d_ACCESS_ACK) begin
                if (verbose)
                    $display("[****:****:memory] ERROR - Store returned unexpected opcode: ", fshow(memoryResponse));
                executedInstruction.exception = tagged Valid createStoreAccessFaultException(storeAddress);
            end else begin
                if (verbose)
                    $display("[****:****:memory] Store completed");
            end

            memoryAccess.wset(MemoryAccess {
                address: storeAddress,
                value: storeRequest.tlRequest.a_data,
                isStore: True
            });
        end else if (executedInstruction.loadRequest matches tagged Valid .loadRequest) begin
            let loadAddress = loadRequest.tlRequest.a_address;
            Word value = ?;
            RVGPRIndex rd = 0; // Any exceptions below that also have writeback data will
                               // write to X0 on completion (instead of any existing RD in the
                               // instruction)

            if (memoryResponse.d_denied) begin
                if (verbose)
                    $display("[****]:****:memory] ERROR - Load returned access denied: ", fshow(memoryResponse));
                executedInstruction.exception = tagged Valid createLoadAccessFaultException(loadAddress);
            end else
            if (memoryResponse.d_corrupt) begin
                if (verbose)
                    $display("[****:****:memory] ERROR - Load returned access corrupted: ", fshow(memoryResponse));                executedInstruction.exception = tagged Valid createLoadAccessFaultException(loadAddress);
            end else
            if (memoryResponse.d_opcode != d_ACCESS_ACK_DATA) begin
                if (verbose)
                    $display("[****:****:memory] ERROR - Load returned unexpected opcode: ", fshow(memoryResponse));
                executedInstruction.exception = tagged Valid createLoadAccessFaultException(loadAddress);
            end else begin
                if (verbose)
                    $display("[****:****:memory] Load completed");

                // Save the data that will be written back into the register file on the
                // writeback pipeline stage.
                rd = loadRequest.rd;

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
                executedInstruction.gprWriteBack = tagged Valid GPRWriteBack {
                    rd: rd,
                    value: value
                };

                memoryAccess.wset(MemoryAccess {
                    address: loadAddress,
                    value: value,
                    isStore: False
                });
            end

            loadResult.wset(value);
        end

        outputQueue.enq(executedInstruction);
    endrule

    interface Put putExecutedInstruction;
        method Action put(ExecutedInstruction executedInstruction) if (waitingForMemoryResponse == False);
            Bool verbose <- $test$plusargs ("verbose");
            let fetchIndex = executedInstruction.fetchIndex;
            let stageEpoch = pipelineController.stageEpoch(stageNumber, 1);
            if (!pipelineController.isCurrentEpoch(stageNumber, 1, executedInstruction.pipelineEpoch)) begin
                if (verbose)
                    $display("%0d,%0d,%0d,%0d,memory access,stale instruction (%0d != %0d)...propagating bubble", 
                        fetchIndex, 
                        cycleCounter, 
                        executedInstruction.pipelineEpoch, 
                        executedInstruction.programCounter, 
                        stageNumber, 
                        executedInstruction.pipelineEpoch, 
                        stageEpoch);
                outputQueue.enq(executedInstruction);
            end else begin
                if(executedInstruction.loadRequest matches tagged Valid .loadRequest) begin
                    if (verbose)
                        $display("%0d,%0d,%0d,%0x,%0d,memory access,LOAD", 
                            fetchIndex, 
                            cycleCounter, 
                            stageEpoch, 
                            executedInstruction.programCounter, 
                            stageNumber);

                    // NOTE: Alignment checks were already performed during the execution stage.
                    dataMemoryRequests.enq(loadRequest.tlRequest);

                    if (verbose)
                        $display("%0d,%0d,%0d,%0x,%0d,memory access,Loading from $%08x with size: %d", 
                            fetchIndex, 
                            cycleCounter, 
                            stageEpoch, 
                            executedInstruction.programCounter, 
                            stageNumber, 
                            loadRequest.tlRequest.a_address, 
                            loadRequest.tlRequest.a_size);
                        instructionWaitingForMemoryOperation <= executedInstruction;
                    waitingForMemoryResponse <= True;
                end else if (executedInstruction.storeRequest matches tagged Valid .storeRequest) begin
                    if (verbose)
                        $display("%0d,%0d,%0d,%0x,%0d,memory access,Storing to $%0x", fetchIndex, cycleCounter, stageEpoch, executedInstruction.programCounter, stageNumber, storeRequest.tlRequest.a_address);
                    dataMemoryRequests.enq(storeRequest.tlRequest);
                    instructionWaitingForMemoryOperation <= executedInstruction;
                    waitingForMemoryResponse <= True;
                end else begin
                    // Not a LOAD/STORE
                    if (verbose)
                        $display("%0d,%0d,%0d,%0x,%0d,memory access,NO-OP", fetchIndex, cycleCounter, stageEpoch, executedInstruction.programCounter, stageNumber);
                    outputQueue.enq(executedInstruction);
                end
            end
        endmethod
    endinterface

    interface Put putCycleCounter = toPut(asIfc(cycleCounter));
    interface Get getExecutedInstruction = toGet(outputQueue);
    interface TileLinkLiteWordClient dataMemoryClient = toGPClient(dataMemoryRequests, dataMemoryResponses);
    interface Get getLoadResult = toGet(loadResult);

    interface Get getMemoryAccess;
        method ActionValue#(Maybe#(MemoryAccess)) get;
            return memoryAccess.wget;
        endmethod
    endinterface
endmodule
