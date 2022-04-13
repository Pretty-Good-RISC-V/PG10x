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
import StageNumbers::*;
import TileLink::*;

import Assert::*;
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

    interface Get#(Maybe#(StdTileLinkRequest)) getInstructionMemoryRequest;
    interface Put#(StdTileLinkResponse) putInstructionMemoryResponse;

    interface Put#(Bool) putAutoFetchEnabled;
    interface Put#(Bool) putExecuteSingleInstruction;

    interface Put#(ProgramCounter) putBranchProgramCounter;
    interface Put#(ProgramCounter) putExceptionProgramCounter;
endinterface

module mkFetchUnit#(
    Reg#(ProgramCounter) programCounter
)(FetchUnit);
    Wire#(Word64) cycleCounter <- mkBypassWire();

    RWire#(StdTileLinkRequest) instructionMemoryRequest <- mkRWire;

    Reg#(Bool) autoFetchEnabled         <- mkReg(False);
    Reg#(Word) fetchCounter             <- mkReg(0);
    Reg#(PipelineEpoch) currentEpoch    <- mkReg(0);
    Reg#(Bool) waitingForMemoryResponse <- mkReg(False);
    Reg#(Bool) singleStepping           <- mkReg(False);

    Reg#(Maybe#(ProgramCounter)) redirectDueToBranch[2]   <- mkCReg(2, tagged Invalid);
    Reg#(Maybe#(ProgramCounter)) redirectDueToException[2] <- mkCReg(2, tagged Invalid);

    FIFO#(FetchInfo) fetchInfoQueue                       <- mkPipelineFIFO; // holds the fetch info for the current instruction request
    FIFO#(StdTileLinkResponse) instructionMemoryResponses <- mkFIFO;
    FIFO#(EncodedInstruction) outputQueue                 <- mkPipelineFIFO;

`ifdef DISABLE_BRANCH_PREDICTOR
    BranchPredictor branchPredictor <- mkNullBranchPredictor;
`else
    BranchPredictor branchPredictor <- mkBackwardBranchTakenPredictor;
`endif

    function ActionValue#(Maybe#(ProgramCounter)) getRedirectedProgramCounter;
        actionvalue
            let redirect = redirectDueToException[1];
            if (!isValid(redirect)) begin
                redirect = redirectDueToBranch[1];
            end

            if (isValid(redirect)) begin
                redirectDueToBranch[1] <= tagged Invalid;
                redirectDueToException[1] <= tagged Invalid;
            end

            return redirect;
        endactionvalue
    endfunction

    function Action sendFetchRequest;
        action
            Bool verbose <- $test$plusargs ("verbose");

            // Get the current program counter from the 'fetchProgramCounter' register, if the 
            // program counter redirect has a value, move that into the program counter and
            // increment the epoch.
            let fetchProgramCounter = programCounter;
            let fetchEpoch = currentEpoch;
            let redirectedProgramCounter <- getRedirectedProgramCounter;

            if (redirectedProgramCounter matches tagged Valid .rpc) begin 
                fetchProgramCounter = rpc;

                fetchEpoch = fetchEpoch + 1;
                currentEpoch <= fetchEpoch;

                if (verbose)
                    $display("%0d,%0d,%0d,%0x,%0d,fetch send,redirected PC: $%08x", fetchCounter, cycleCounter, fetchEpoch, fetchProgramCounter, valueOf(FetchStageNumber), fetchProgramCounter);
            end

            if (verbose)
                $display("%0d,%0d,%0d,%0x,%0d,fetch send,fetch address: $%08x", fetchCounter, cycleCounter, fetchEpoch, fetchProgramCounter, valueOf(FetchStageNumber), fetchProgramCounter);

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
        endaction
    endfunction

    (* fire_when_enabled *)
    rule autoFetchHandler(autoFetchEnabled && !waitingForMemoryResponse);
        sendFetchRequest;
    endrule

    (* fire_when_enabled *)
    rule handleFetchResponse(waitingForMemoryResponse);
        Bool verbose <- $test$plusargs ("verbose");
        let fetchResponse <- pop(instructionMemoryResponses);
        let fetchInfo <- pop(fetchInfoQueue);
        Maybe#(Exception) exception = tagged Invalid;

        if (fetchResponse.d_denied) begin
            if (verbose)
                $display("%0d,%0d,%0d,%0x,%0d,fetch receive,EXCEPTION - received access denied from memory system.", fetchInfo.index, cycleCounter, fetchInfo.epoch, fetchInfo.address, valueOf(FetchStageNumber));
`ifdef ENABLE_RISCOF_TESTS
            if (fetchInfo.address == 'hc0dec0de)
                exception = tagged Valid createRISCOFTestHaltException(fetchInfo.address);
            else
`endif
            exception = tagged Valid createInstructionAccessFaultException(fetchInfo.address);
        end else if (fetchResponse.d_corrupt) begin
            if (verbose)
                $display("%0d,%0d,%0d,%0x,%0d,fetch receive,EXCEPTION - received corrupted data from memory system.", fetchInfo.index, cycleCounter, fetchInfo.epoch, fetchInfo.address, valueOf(FetchStageNumber));
            exception = tagged Valid createInstructionAccessFaultException(fetchInfo.address);
        end else if (fetchResponse.d_opcode != d_ACCESS_ACK_DATA) begin
            if (verbose)
                $display("%0d,%0d,%0d,%0x,%0d,fetch receive,EXCEPTION - received unexpected opcode from memory system: ", fetchInfo.index, cycleCounter, fetchInfo.epoch, fetchInfo.address, valueOf(FetchStageNumber), fshow(fetchResponse.d_opcode));
            exception = tagged Valid createInstructionAccessFaultException(fetchInfo.address);
        end else begin
            if (verbose)
                $display("%0d,%0d,%0d,%0x,%0d,fetch receive,encoded instruction=%08h", fetchInfo.index, cycleCounter, fetchInfo.epoch, fetchInfo.address, valueOf(FetchStageNumber), fetchResponse.d_data);
        end

        // Predict what the next program counter will be
        let predictedNextProgramCounter = branchPredictor.predictNextProgramCounter(fetchInfo.address, fetchResponse.d_data[31:0]);
        if (verbose)
            $display("%0d,%0d,%0d,%0x,%0d,fetch receive,predicted next instruction=$%x", fetchInfo.index, cycleCounter, fetchInfo.epoch, fetchInfo.address, valueOf(FetchStageNumber), predictedNextProgramCounter);
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

    interface Get getInstructionMemoryRequest;
        method ActionValue#(Maybe#(StdTileLinkRequest)) get;
            return instructionMemoryRequest.wget();
        endmethod
    endinterface

    interface Put putInstructionMemoryResponse = toPut(asIfc(instructionMemoryResponses));
    interface Put putAutoFetchEnabled = toPut(asIfc(autoFetchEnabled));

    interface Put putExecuteSingleInstruction;
        method Action put(Bool executeSingleInstruction);
            if (autoFetchEnabled == False) begin
                dynamicAssert(executeSingleInstruction == True, "");
                sendFetchRequest;
            end
        endmethod
    endinterface

    interface Put putBranchProgramCounter;
        method Action put(ProgramCounter branchTarget);
            redirectDueToBranch[0] <= tagged Valid branchTarget;
        endmethod
    endinterface

    interface Put putExceptionProgramCounter;
        method Action put(ProgramCounter exceptionHandler);
            redirectDueToException[0] <= tagged Valid exceptionHandler;
        endmethod
    endinterface
endmodule
