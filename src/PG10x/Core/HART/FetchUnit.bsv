//
// FetchUnit
//
// This module is a RISC-V instruction fetch unit.  It is responsible for fetching instructions 
// from memory and creating a EncodedInstruction structure representing them.
//
`include "PGLib.bsh"

import BranchPredictor::*;
import EncodedInstruction::*;
import PipelineController::*;
import ProgramCounterRedirect::*;
import TileLink::*;

import ClientServer::*;
import FIFO::*;
import GetPut::*;
import SpecialFIFOs::*;

export mkFetchUnit, FetchUnit(..);

typedef struct {
    PipelineEpoch epoch;
    Word address;
    Word index;     // The fetch index
} FetchInfo deriving(Bits, Eq, FShow);

interface FetchUnit;
    interface Get#(EncodedInstruction) getEncodedInstruction;

    interface TileLinkLiteWordClient#(XLEN) instructionMemoryClient;

    interface Put#(Bool) putFetchEnabled;
endinterface

module mkFetchUnit#(
    ReadOnly#(Word64) cycleCounter,
    Integer stageNumber,
    Reg#(ProgramCounter) programCounter,
    ProgramCounterRedirect programCounterRedirect
)(FetchUnit);
    Reg#(Bool) fetchEnabled <- mkReg(False);
    Reg#(Word) fetchCounter <- mkReg(0);
    Reg#(PipelineEpoch) currentEpoch <- mkReg(0);
    Reg#(Bool) waitingForMemoryResponse <- mkReg(False);

    FIFO#(FetchInfo) fetchInfoQueue <- mkPipelineFIFO; // holds the fetch info for the current instruction request

    FIFO#(TileLinkLiteWordRequest#(XLEN)) instructionMemoryRequests <- mkFIFO;
    FIFO#(TileLinkLiteWordResponse#(XLEN)) instructionMemoryResponses <- mkFIFO;

    FIFO#(EncodedInstruction) outputQueue <- mkPipelineFIFO;

`ifdef DISABLE_BRANCH_PREDICTOR
    BranchPredictor branchPredictor <- mkNullBranchPredictor;
`else
    BranchPredictor branchPredictor <- mkBackwardBranchTakenPredictor;
`endif

    (* fire_when_enabled *)
    rule sendFetchRequest(fetchEnabled == True && !waitingForMemoryResponse);
        // Get the current program counter from the 'fetchProgramCounter' register, if the 
        // program counter redirect has a value, move that into the program counter and
        // increment the epoch.
        let fetchProgramCounter = programCounter;
        let fetchEpoch = currentEpoch;
        let redirectedProgramCounter <- programCounterRedirect.getRedirectedProgramCounter;
        if (redirectedProgramCounter matches tagged Valid .rpc) begin 
            fetchProgramCounter = rpc;

            fetchEpoch = fetchEpoch + 1;
            currentEpoch <= fetchEpoch;

            $display("%0d,%0d,%0d,%0x,%0d,fetch send,redirected PC: $%08x", fetchCounter, cycleCounter, fetchEpoch, fetchProgramCounter, stageNumber, fetchProgramCounter);
        end

        $display("%0d,%0d,%0d,%0x,%0d,fetch send,fetch address: $%08x", fetchCounter, cycleCounter, fetchEpoch, fetchProgramCounter, stageNumber, fetchProgramCounter);

        instructionMemoryRequests.enq(TileLinkLiteWordRequest {
            a_opcode: a_GET,
            a_param: 0,
            a_size: 2, // Log2(sizeof(Word32))
            a_source: 0,
            a_address: fetchProgramCounter,
            a_mask: 'b1111,
            a_data: ?,
            a_corrupt: False
        });

        fetchInfoQueue.enq(FetchInfo {
            epoch: fetchEpoch,
            address: fetchProgramCounter,
            index: fetchCounter
        });

        waitingForMemoryResponse <= True;
        fetchCounter <= fetchCounter + 1;
    endrule

    (* fire_when_enabled *)
    rule handleFetchResponse(waitingForMemoryResponse);
        let fetchResponse = instructionMemoryResponses.first;
        instructionMemoryResponses.deq;

        let fetchInfo = fetchInfoQueue.first;
        fetchInfoQueue.deq;

        if (fetchResponse.d_denied) begin
            $display("%0d,%0d,%0d,%0x,%0d,fetch receive,FATAL - received access denied from memory system.", fetchInfo.index, cycleCounter, fetchInfo.epoch, fetchInfo.address, stageNumber);
            $fatal();
        end else if (fetchResponse.d_corrupt) begin
            $display("%0d,%0d,%0d,%0x,%0d,fetch receive,FATAL - received corrupted data from memory system.", fetchInfo.index, cycleCounter, fetchInfo.epoch, fetchInfo.address, stageNumber);
            $fatal();
        end else if (fetchResponse.d_opcode != d_ACCESS_ACK_DATA) begin
            $display("%0d,%0d,%0d,%0x,%0d,fetch receive,FATAL - received unexpected opcode from memory system: ", fetchInfo.index, cycleCounter, fetchInfo.epoch, fetchInfo.address, stageNumber, fshow(fetchResponse.d_opcode));
            $fatal();
        end else begin
            $display("%0d,%0d,%0d,%0x,%0d,fetch receive,encoded instruction=%08h", fetchInfo.index, cycleCounter, fetchInfo.epoch, fetchInfo.address, stageNumber, fetchResponse.d_data);

            // Predict what the next program counter will be
            let predictedNextProgramCounter = branchPredictor.predictNextProgramCounter(fetchInfo.address, fetchResponse.d_data[31:0]);
            $display("%0d,%0d,%0d,%0x,%0d,fetch receive,predicted next instruction=$%x", fetchInfo.index, cycleCounter, fetchInfo.epoch, fetchInfo.address, stageNumber, predictedNextProgramCounter);
            programCounter <= predictedNextProgramCounter;

            // Tell the decode stage what the program counter for the insruction it'll receive.
            outputQueue.enq(EncodedInstruction {
                fetchIndex: fetchInfo.index,
                programCounter: fetchInfo.address,
                predictedNextProgramCounter: predictedNextProgramCounter,
                pipelineEpoch: fetchInfo.epoch,
                rawInstruction: fetchResponse.d_data[31:0]
            });
        end

        waitingForMemoryResponse <= False;
    endrule

    interface Get getEncodedInstruction = toGet(outputQueue);
    interface TileLinkLiteWordClient instructionMemoryClient = toGPClient(instructionMemoryRequests, instructionMemoryResponses);
    interface Put putFetchEnabled = toPut(asIfc(fetchEnabled));
endmodule
