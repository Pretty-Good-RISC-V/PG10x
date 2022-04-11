//
// FetchUnit
//
// This module is a RISC-V instruction fetch unit.  It is responsible for fetching instructions 
// from memory and creating a EncodedInstruction structure representing them.
//
`include "PGLib.bsh"

import BranchPredictor::*;
import EncodedInstruction::*;
import Exception::*;
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
    interface Put#(Word64) putCycleCounter;
    interface Get#(EncodedInstruction) getEncodedInstruction;
//    interface StdTileLinkClient instructionMemoryClient;

    interface Get#(Maybe#(StdTileLinkRequest)) getInstructionMemoryRequest;
    interface Put#(StdTileLinkResponse) putInstructionMemoryResponse;

    interface Put#(Bool) putFetchEnabled;
    interface Put#(Bool) putSingleStepping;

    method Action step;
endinterface

module mkFetchUnit#(
    Integer stageNumber,
    Reg#(ProgramCounter) programCounter,
    ProgramCounterRedirect programCounterRedirect
)(FetchUnit);
    Wire#(Word64) cycleCounter <- mkBypassWire();

    Reg#(Bool) fetchEnabled <- mkReg(False);
    Reg#(Word) fetchCounter <- mkReg(0);
    Reg#(PipelineEpoch) currentEpoch <- mkReg(0);
    Reg#(Bool) waitingForMemoryResponse <- mkReg(False);

    FIFO#(FetchInfo) fetchInfoQueue <- mkPipelineFIFO; // holds the fetch info for the current instruction request

//    FIFO#(StdTileLinkRequest) instructionMemoryRequests <- mkFIFO;
    FIFO#(StdTileLinkResponse) instructionMemoryResponses <- mkFIFO;

    RWire#(StdTileLinkRequest) instructionMemoryRequest <- mkRWire;

    FIFO#(EncodedInstruction) outputQueue <- mkPipelineFIFO;

`ifdef DISABLE_BRANCH_PREDICTOR
    BranchPredictor branchPredictor <- mkNullBranchPredictor;
`else
    BranchPredictor branchPredictor <- mkBackwardBranchTakenPredictor;
`endif

    Reg#(Bool) singleStepping <- mkReg(False);

    (* fire_when_enabled *)
    rule sendFetchRequest(fetchEnabled == True && !waitingForMemoryResponse);
        Bool verbose <- $test$plusargs ("verbose");

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

            if (verbose)
                $display("%0d,%0d,%0d,%0x,%0d,fetch send,redirected PC: $%08x", fetchCounter, cycleCounter, fetchEpoch, fetchProgramCounter, stageNumber, fetchProgramCounter);
        end

        if (verbose)
            $display("%0d,%0d,%0d,%0x,%0d,fetch send,fetch address: $%08x", fetchCounter, cycleCounter, fetchEpoch, fetchProgramCounter, stageNumber, fetchProgramCounter);

        //instructionMemoryRequests.enq(TileLinkLiteWordRequest {
        instructionMemoryRequest.wset(TileLinkLiteWordRequest {
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

        if (singleStepping) begin
            fetchEnabled <= False;
        end
    endrule

    (* fire_when_enabled *)
    rule handleFetchResponse(waitingForMemoryResponse);
        Bool verbose <- $test$plusargs ("verbose");
        let fetchResponse <- pop(instructionMemoryResponses);
        let fetchInfo <- pop(fetchInfoQueue);
        Maybe#(Exception) exception = tagged Invalid;

        if (fetchResponse.d_denied) begin
            if (verbose)
                $display("%0d,%0d,%0d,%0x,%0d,fetch receive,EXCEPTION - received access denied from memory system.", fetchInfo.index, cycleCounter, fetchInfo.epoch, fetchInfo.address, stageNumber);
`ifdef ENABLE_RISCOF_TESTS
            if (fetchInfo.address == 'hc0dec0de)
                exception = tagged Valid createRISCOFTestHaltException(fetchInfo.address);
            else
`endif
            exception = tagged Valid createInstructionAccessFaultException(fetchInfo.address);
        end else if (fetchResponse.d_corrupt) begin
            if (verbose)
                $display("%0d,%0d,%0d,%0x,%0d,fetch receive,EXCEPTION - received corrupted data from memory system.", fetchInfo.index, cycleCounter, fetchInfo.epoch, fetchInfo.address, stageNumber);
            exception = tagged Valid createInstructionAccessFaultException(fetchInfo.address);
        end else if (fetchResponse.d_opcode != d_ACCESS_ACK_DATA) begin
            if (verbose)
                $display("%0d,%0d,%0d,%0x,%0d,fetch receive,EXCEPTION - received unexpected opcode from memory system: ", fetchInfo.index, cycleCounter, fetchInfo.epoch, fetchInfo.address, stageNumber, fshow(fetchResponse.d_opcode));
            exception = tagged Valid createInstructionAccessFaultException(fetchInfo.address);
        end else begin
            if (verbose)
                $display("%0d,%0d,%0d,%0x,%0d,fetch receive,encoded instruction=%08h", fetchInfo.index, cycleCounter, fetchInfo.epoch, fetchInfo.address, stageNumber, fetchResponse.d_data);
        end

        // Predict what the next program counter will be
        let predictedNextProgramCounter = branchPredictor.predictNextProgramCounter(fetchInfo.address, fetchResponse.d_data[31:0]);
        if (verbose)
            $display("%0d,%0d,%0d,%0x,%0d,fetch receive,predicted next instruction=$%x", fetchInfo.index, cycleCounter, fetchInfo.epoch, fetchInfo.address, stageNumber, predictedNextProgramCounter);
        programCounter <= predictedNextProgramCounter;

        // Tell the decode stage what the program counter for the insruction it'll receive.
        outputQueue.enq(EncodedInstruction {
            fetchIndex: fetchInfo.index,
            programCounter: fetchInfo.address,
            predictedNextProgramCounter: predictedNextProgramCounter,
            pipelineEpoch: fetchInfo.epoch,
            rawInstruction: fetchResponse.d_data[31:0],
            exception: exception
        });

        waitingForMemoryResponse <= False;
    endrule

    interface Put putCycleCounter = toPut(asIfc(cycleCounter));
    interface Get getEncodedInstruction = toGet(outputQueue);
//    interface TileLinkLiteWordClient instructionMemoryClient = toGPClient(instructionMemoryRequests, instructionMemoryResponses);


    interface Get getInstructionMemoryRequest;
        method ActionValue#(Maybe#(StdTileLinkRequest)) get;
            return instructionMemoryRequest.wget();
        endmethod
    endinterface

    interface Put putInstructionMemoryResponse = toPut(asIfc(instructionMemoryResponses));


    interface Put putFetchEnabled = toPut(asIfc(fetchEnabled));
    interface Put putSingleStepping = toPut(asIfc(singleStepping));

    method Action step if(fetchEnabled == False);
        fetchEnabled <= True;
    endmethod
endmodule
