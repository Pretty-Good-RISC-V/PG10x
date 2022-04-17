//
// FetchUnit
//
// This module is a RISC-V instruction fetch unit.  It is responsible for fetching instructions 
// from memory and creating a EncodedInstruction structure representing them.
//
`include "PGLib.bsvi"
`include "HART.bsvi"

import BranchPredictor::*;
import EncodedInstruction::*;
import Exception::*;
import InstructionCommon::*;
import StageNumbers::*;
import TileLink::*;

import Assert::*;
import ClientServer::*;
import FIFO::*;
import GetPut::*;
import SpecialFIFOs::*;

export mkFetchUnit, FetchUnit(..);

interface FetchUnit;
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
    RWire#(StdTileLinkRequest) instructionMemoryRequest <- mkRWire;

    Reg#(Bool) autoFetchEnabled         <- mkReg(False);
    Reg#(Word) fetchCounter             <- mkReg(0);
    Reg#(PipelineEpoch) currentEpoch    <- mkReg(0);
    Reg#(Bool) waitingForMemoryResponse <- mkReg(False);
    Reg#(Bool) singleStepping           <- mkReg(False);

    Reg#(Maybe#(ProgramCounter)) redirectDueToBranch[2]   <- mkCReg(2, tagged Invalid);
    Reg#(Maybe#(ProgramCounter)) redirectDueToException[2] <- mkCReg(2, tagged Invalid);

    FIFO#(InstructionCommon) fetchInfoQueue               <- mkPipelineFIFO; // info about the instruction being fetched
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
            // Create an instruction common structure - this'll be the common
            // struction of the instruction as it goes through the pipeline.
            let instructionCommon = InstructionCommon {
                fetchIndex: fetchCounter,
                pipelineEpoch: currentEpoch,
                programCounter: programCounter,
                rawInstruction: ?,
                predictedNextProgramCounter: ?
            };

            let redirectedProgramCounter <- getRedirectedProgramCounter;
            if (redirectedProgramCounter matches tagged Valid .rpc) begin 
                `stageLog(instructionCommon, FetchStageNumber, $format("redirected PC: $%08x", rpc))

                instructionCommon.programCounter = rpc;
                instructionCommon.pipelineEpoch = instructionCommon.pipelineEpoch + 1;

                currentEpoch <= instructionCommon.pipelineEpoch;
            end

            `stageLog(instructionCommon, FetchStageNumber, $format("fetch address: $%08x", instructionCommon.programCounter))

            instructionMemoryRequest.wset(TileLinkLiteWordRequest {
                a_opcode: a_GET,
                a_param: 0,
                a_size: 2, // Log2(sizeof(Word32))
                a_source: 0,
                a_address: instructionCommon.programCounter,
                a_mask: 'b1111,
                a_data: ?,
                a_corrupt: False
            });

            fetchInfoQueue.enq(instructionCommon);

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
        let fetchResponse <- pop(instructionMemoryResponses);
        let instructionCommon <- pop(fetchInfoQueue);
        Maybe#(Exception) exception = tagged Invalid;

        if (fetchResponse.d_denied) begin
            `stageLog(instructionCommon, FetchStageNumber, "EXCEPTION - received access denied from memory system")

`ifdef ENABLE_RISCOF_TESTS
            if (instructionCommon.programCounter == 'hc0dec0de)
                exception = tagged Valid createRISCOFTestHaltException(instructionCommon.programCounter);
            else
`endif
            exception = tagged Valid createInstructionAccessFaultException(instructionCommon.programCounter);
        end else if (fetchResponse.d_corrupt) begin
            `stageLog(instructionCommon, FetchStageNumber, "EXCEPTION - received corrupted data from memory system")

            exception = tagged Valid createInstructionAccessFaultException(instructionCommon.programCounter);
        end else if (fetchResponse.d_opcode != d_ACCESS_ACK_DATA) begin
            `stageLog(instructionCommon, FetchStageNumber, $format("EXCEPTION - received unexpected opcode from memory system: ", fshow(fetchResponse.d_opcode)))

            exception = tagged Valid createInstructionAccessFaultException(instructionCommon.programCounter);
        end else begin
            `stageLog(instructionCommon, FetchStageNumber, $format("encoded instruction=$%08h", fetchResponse.d_data))
        end

        // Predict what the next program counter will be
        let predictedNextProgramCounter = branchPredictor.predictNextProgramCounter(instructionCommon.programCounter, fetchResponse.d_data[31:0]);

        `stageLog(instructionCommon, FetchStageNumber, $format("predicted next instruction=$%0x", predictedNextProgramCounter))

        programCounter <= predictedNextProgramCounter;

        // Tell the decode stage what the program counter for the insruction it'll receive.
        instructionCommon.predictedNextProgramCounter = predictedNextProgramCounter;
        instructionCommon.rawInstruction = fetchResponse.d_data[31:0];

        outputQueue.enq(EncodedInstruction {
            instructionCommon: instructionCommon,
            exception: exception
        });

        waitingForMemoryResponse <= False;
    endrule

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
