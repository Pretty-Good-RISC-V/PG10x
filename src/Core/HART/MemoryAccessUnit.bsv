//
// MemoryAccessUnit
//
// This module is responsible for handling RISC-V LOAD and STORE instructions.  It 
// accepts a 'ExecutedInstruction' structure and if the values contained therein have
// valid LoadRequest or StoreRequest structures, the requisite load and store operations
// are executed.
//
`include "PGLib.bsvi"
`include "HART.bsvi"

import EncodedInstruction::*;
import Exception::*;
import ExecutedInstruction::*;
import InstructionCommon::*;
import LoadStore::*;
import StageNumbers::*;
import TileLink::*;

import Assert::*;
import ClientServer::*;
import FIFO::*;
import GetPut::*;
import SpecialFIFOs::*;

export MemoryAccessUnit(..), mkMemoryAccessUnit, MemoryAccess(..);

typedef struct {
    Address address;
    Word value;
    Bool isStore;
} MemoryAccess deriving(Bits, Eq, FShow);

interface MemoryAccessUnit;
    interface Put#(ExecutedInstruction) putExecutedInstruction;
    interface Get#(ExecutedInstruction) getExecutedInstruction;

    interface StdTileLinkClient dataMemoryClient;

    interface Get#(Maybe#(Word)) getLoadResult;
    interface Get#(Maybe#(MemoryAccess)) getMemoryAccess;
endinterface

module mkMemoryAccessUnit(MemoryAccessUnit);
    FIFO#(ExecutedInstruction) outputQueue <- mkPipelineFIFO;
    RWire#(MemoryAccess) memoryAccess <- mkRWire;

    Reg#(Bool) waitingForMemoryResponse <- mkReg(False);

    Reg#(ExecutedInstruction) instructionWaitingForMemoryOperation <- mkRegU;
    FIFO#(StdTileLinkRequest) dataMemoryRequests <- mkFIFO;
    FIFO#(StdTileLinkResponse) dataMemoryResponses <- mkFIFO;

    FIFO#(Maybe#(Word)) loadResultQueue <- mkBypassFIFO;

    rule handleMemoryResponse(waitingForMemoryResponse == True);
        let memoryResponse <- pop(dataMemoryResponses);
        let executedInstruction = instructionWaitingForMemoryOperation;
        waitingForMemoryResponse <= False;

        if (executedInstruction.storeRequest matches tagged Success .storeRequest) begin
            let storeAddress = storeRequest.tlRequest.a_address;
            if (memoryResponse.d_denied) begin
                `stageLog(executedInstruction.instructionCommon, MemoryAccessStageNumber, $format("ERROR - store returned access denied: ", fshow(memoryResponse)))
                executedInstruction.exception = tagged Valid createStoreAccessFaultException(storeAddress);
            end else
            if (memoryResponse.d_corrupt) begin
                `stageLog(executedInstruction.instructionCommon, MemoryAccessStageNumber, $format("ERROR - store returned access corrupted: ", fshow(memoryResponse)))
                executedInstruction.exception = tagged Valid createStoreAccessFaultException(storeAddress);
            end else
            if (memoryResponse.d_opcode != d_ACCESS_ACK) begin
                `stageLog(executedInstruction.instructionCommon, MemoryAccessStageNumber, $format("ERROR - store returned unexpected opcode: ", fshow(memoryResponse)))
                executedInstruction.exception = tagged Valid createStoreAccessFaultException(storeAddress);
            end else begin
                `stageLog(executedInstruction.instructionCommon, MemoryAccessStageNumber, "store completed")
            end

            memoryAccess.wset(MemoryAccess {
                address: storeAddress,
                value: storeRequest.tlRequest.a_data,
                isStore: True
            });
        end else if (executedInstruction.loadRequest matches tagged Success .loadRequest) begin
            let loadAddress = loadRequest.tlRequest.a_address;
            Word value = ?;
            RVGPRIndex rd = 0; // Any exceptions below that also have writeback data will
                               // write to X0 on completion (instead of any existing RD in the
                               // instruction)

            if (memoryResponse.d_denied) begin
                `stageLog(executedInstruction.instructionCommon, MemoryAccessStageNumber, $format("ERROR - load returned access denied: ", fshow(memoryResponse)))
                executedInstruction.exception = tagged Valid createLoadAccessFaultException(loadAddress);
            end else
            if (memoryResponse.d_corrupt) begin
                `stageLog(executedInstruction.instructionCommon, MemoryAccessStageNumber, $format("ERROR - load returned access corrupted: ", fshow(memoryResponse)))
                executedInstruction.exception = tagged Valid createLoadAccessFaultException(loadAddress);
            end else
            if (memoryResponse.d_opcode != d_ACCESS_ACK_DATA) begin
                `stageLog(executedInstruction.instructionCommon, MemoryAccessStageNumber, $format("ERROR - load returned unexpected opcode:: ", fshow(memoryResponse)))
                executedInstruction.exception = tagged Valid createLoadAccessFaultException(loadAddress);
            end else begin
                `stageLog(executedInstruction.instructionCommon, MemoryAccessStageNumber, "load completed")

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
                executedInstruction.gprWriteBack = tagged Success GPRWriteBack {
                    rd: rd,
                    value: value
                };

                memoryAccess.wset(MemoryAccess {
                    address: loadAddress,
                    value: value,
                    isStore: False
                });
            end

            loadResultQueue.enq(tagged Valid value);
        end

        outputQueue.enq(executedInstruction);
    endrule

    interface Put putExecutedInstruction;
        method Action put(ExecutedInstruction executedInstruction) if (waitingForMemoryResponse == False);
            Bool verbose <- $test$plusargs ("verbose");
            let fetchIndex = executedInstruction.instructionCommon.fetchIndex;
            if(executedInstruction.loadRequest matches tagged Success .loadRequest) begin
                `stageLog(executedInstruction.instructionCommon, MemoryAccessStageNumber, 
                    $format("loading from $%08x with size %d", 
                    loadRequest.tlRequest.a_address, 
                    loadRequest.tlRequest.a_size))

                dataMemoryRequests.enq(loadRequest.tlRequest);
                instructionWaitingForMemoryOperation <= executedInstruction;
                waitingForMemoryResponse <= True;
            end else if (executedInstruction.storeRequest matches tagged Success .storeRequest) begin
                `stageLog(executedInstruction.instructionCommon, MemoryAccessStageNumber, 
                    $format("storing to $%08x with size %d and value %d", 
                    storeRequest.tlRequest.a_address,
                    storeRequest.tlRequest.a_size, 
                    storeRequest.tlRequest.a_data))

                dataMemoryRequests.enq(storeRequest.tlRequest);
                instructionWaitingForMemoryOperation <= executedInstruction;
                waitingForMemoryResponse <= True;
            end else begin
                `stageLog(executedInstruction.instructionCommon, MemoryAccessStageNumber, "No memory operations in this instruction")
                outputQueue.enq(executedInstruction);
            end
        endmethod
    endinterface

    interface Get getExecutedInstruction = toGet(outputQueue);
    interface TileLinkLiteWordClient dataMemoryClient = toGPClient(dataMemoryRequests, dataMemoryResponses);
    interface Get getLoadResult = toGet(loadResultQueue);

    interface Get getMemoryAccess;
        method ActionValue#(Maybe#(MemoryAccess)) get;
            return memoryAccess.wget;
        endmethod
    endinterface
endmodule
