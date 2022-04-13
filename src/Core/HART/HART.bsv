import PGTypes::*;

import ALU::*;
import BypassController::*;
import Debug::*;
import DecodeUnit::*;
import TrapController::*;
import ExecutionUnit::*;
import FetchUnit::*;
import GPRFile::*;
import MemoryAccessUnit::*;
import PipelineController::*;
import Scoreboard::*;
import TileLink::*;
import WritebackUnit::*;

import Connectable::*;
import FIFO::*;
import FIFOF::*;
import GetPut::*;
import SpecialFIFOs::*;

// ================================================================
// Exports
export HARTState(..), HART (..), mkHART, MemoryAccess;

//
// HARTState - roughy follows the RISC-V debug spec for hart states.
//
typedef enum {
    RESET,          // -> STARTING, -> HALTING
    STARTING,       // -> RUNNING,
    RUNNING,        // -> HALTING, -> QUITTING
    HALTING,        // -> HALTED
    HALTED,         // -> RESUMING, -> STEPPING, -> QUITTING
    RESUMING,       // -> RUNNING
    STEPPING,       // -> HALTED
    QUITTING
} HARTState deriving(Bits, Eq, FShow);

interface HART;
    method Action start;
    method HARTState getState;

    interface Get#(Maybe#(StdTileLinkRequest)) getInstructionMemoryRequest;
    interface Put#(StdTileLinkResponse) putInstructionMemoryResponse;
    interface StdTileLinkClient dataMemoryClient;

    interface Put#(Bool) putPipeliningEnabled;

    interface Debug debug;

    interface Get#(Maybe#(MemoryAccess)) getMemoryAccess;

`ifdef ENABLE_RISCOF_TESTS
    interface Get#(Bool) getRISCOFHaltRequested;
`endif

endinterface

//
// Pipeline Stages
// 1. Instruction Fetch
//      - In this stage CPU reads instructions from memory address located in the Program Counter.
// 2. Instruction Decode
//      - In this stage, instruction is decoded and the register file accessed to get values from registers used in the instruction.
// 3. Instruction Execution
//      - In this stage, the decoded instruction is executed
// 4. Memory Access
//      - In this stage, memory operands are read/written that is present in the instruction.
// 5. Write Back
//      - In this stage, computed/fetched values are written back to the register file present in the instruction.
//
module mkHART#(
    ProgramCounter initialProgramCounter
)(HART);
    Reg#(Bool) pipeliningEnabled <- mkReg(True);

    //
    // HARTState
    //
    Reg#(HARTState) hartState <- mkReg(RESET);

    //
    // Cycle counter
    //
    Reg#(Word64) cycleCounter <- mkReg(0);

    //
    // CPU Halt Flag
    //
    Reg#(Bool) halt <- mkReg(False);

    //
    // GPR File
    //
    GPRFile gprFile <- mkGPRFile;

    //
    // Trap controller (and CSRFile)
    //
    TrapController trapController <- mkTrapController;

    //
    // Scoreboard
    //
    Scoreboard#(4) scoreboard <- mkScoreboard;

    //
    // Pipeline stage epochs
    //
    PipelineController pipelineController <- mkPipelineController(7 /* stage count */);

    //
    // Program Counter
    //
    Reg#(ProgramCounter) programCounter <- mkReg(initialProgramCounter);

    //
    // Stage 1 - Instruction fetch
    //
    FetchUnit fetchUnit <- mkFetchUnit(
        1,  // stage number
        programCounter
    );

    mkConnection(toGet(cycleCounter), fetchUnit.putCycleCounter);

    //
    // Stage 2 - Instruction Decode
    //
    DecodeUnit decodeUnit <- mkDecodeUnit(
        2,  // stage number
        pipelineController,
        gprFile,
        trapController.csrFile,
        scoreboard
    );

    mkConnection(toGet(cycleCounter), decodeUnit.putCycleCounter);
    mkConnection(fetchUnit.getEncodedInstruction, decodeUnit.putEncodedInstruction);

    //
    // Stage 3 - Instruction execution
    //
    ExecutionUnit executionUnit <- mkExecutionUnit(
        3,  // stage number
        pipelineController,
        trapController,
        scoreboard
    );

    mkConnection(toGet(cycleCounter), executionUnit.putCycleCounter);
    mkConnection(decodeUnit.getDecodedInstruction, executionUnit.putDecodedInstruction);

    // Bypasses from the execution unit to the program counter redirect
    mkConnection(executionUnit.getBranchProgramCounterRedirection, fetchUnit.putBranchProgramCounter);

    // Bypasses from the execution unit to the decode unit
    mkConnection(executionUnit.getExecutionDestination, decodeUnit.putExecutionDestination);
    mkConnection(executionUnit.getExecutionResult, decodeUnit.putExecutionResult);
    mkConnection(executionUnit.getLoadDestination, decodeUnit.putLoadDestination);

    mkConnection(toGet(halt), executionUnit.putHalt);

    //
    // Stage 4 - Memory access
    //
    MemoryAccessUnit memoryAccessUnit <- mkMemoryAccessUnit(
        4,
        pipelineController
    );

    mkConnection(toGet(cycleCounter), memoryAccessUnit.putCycleCounter);
    mkConnection(executionUnit.getExecutedInstruction, memoryAccessUnit.putExecutedInstruction);

    // Bypasses from the memory unit to the decode unit
    mkConnection(memoryAccessUnit.getLoadResult, decodeUnit.putLoadResult);

    // 
    // Stage 5 - Register Writeback
    //
    WritebackUnit writebackUnit <- mkWritebackUnit(
        5,
        pipelineController,
        gprFile,
        trapController,
        scoreboard
    );

    mkConnection(toGet(cycleCounter), writebackUnit.putCycleCounter);
    mkConnection(memoryAccessUnit.getExecutedInstruction, writebackUnit.putExecutedInstruction);

    // Bypasses from the writeback unit to the program counter redirect
    mkConnection(writebackUnit.getExceptionProgramCounterRedirection, fetchUnit.putExceptionProgramCounter);

    // Connection to allow unpipelined operation
    mkConnection(writebackUnit.getInstructionRetired, fetchUnit.putExecuteSingleInstruction);

    //
    // State handlers
    //
    FIFO#(HARTState) stateTransitionQueue <- mkFIFO;
    Reg#(Bit#(8)) haltDelay <- mkRegU();
    function Action changeState(HARTState newState);
        action
        // Ensure transition is valid
        let transitionAllowed = False;
        case (newState)
            STARTING: if (hartState == RESET) transitionAllowed = True;
            RUNNING:  if (hartState == STARTING || hartState == RESUMING) transitionAllowed = True;
            HALTING:  begin
                if (hartState == RUNNING || hartState == RESET) begin
                    transitionAllowed = True;
                    haltDelay <= 10;
                end
            end
            HALTED:   if (hartState == HALTING || hartState == STEPPING) transitionAllowed = True;
            RESUMING: if (hartState == HALTED) transitionAllowed = True;
            STEPPING: if (hartState == HALTED) transitionAllowed = True;
        endcase

        if (transitionAllowed) begin
            stateTransitionQueue.enq(newState);
        end else begin
            $display("Invalid state transition requested: ", fshow(hartState), " -> ", fshow(newState));
            $fatal();
        end
        endaction
    endfunction

    //
    // STARTING
    //
    rule handleStartingState(hartState == STARTING);
        changeState(RUNNING);
    endrule

    //
    // RUNNING
    //
    Reg#(Bool) firstRun <- mkReg(True);
    (* fire_when_enabled *)
    rule handleRunningState(hartState == RUNNING);
        if (firstRun) begin
            $display("FetchIndex,Cycle,Pipeline Epoch,Program Counter,Stage Number,Stage Name,Info");

            fetchUnit.putAutoFetchEnabled.put(True);
            firstRun <= False;
        end

        if (!pipeliningEnabled && !firstRun) begin
            // let wasRetired = writebackUnit.wasInstructionRetired;
            // if (wasRetired) begin
            //     fetchUnit.step;
            // end
        end
    endrule

    //
    // HALTING
    //
    rule handleHaltingState(hartState == HALTING);
        fetchUnit.putAutoFetchEnabled.put(False);

        // Wait for the pipeline to flush
        if (haltDelay > 0) begin
            haltDelay <= haltDelay - 1;
        end else begin
            changeState(HALTED);
        end
    endrule

    //
    // RESUMING
    //
    rule handleResumingState(hartState == RESUMING);
        fetchUnit.putAutoFetchEnabled.put(True);
        changeState(RUNNING);
    endrule

    //
    // QUITTING
    //
    rule handleQuittingState(hartState == QUITTING);
        $display("CPU HALTED. Cycles: %0d - Instructions retired: %0d", trapController.csrFile.cycle_counter, trapController.csrFile.instructions_retired_counter);
        $finish();
    endrule

    (* fire_when_enabled *)
    rule handleStateTransition;
        let newState <- pop(stateTransitionQueue);
        hartState <= newState;
    endrule


    (* fire_when_enabled, no_implicit_conditions *)
    rule incrementCycleCounter;
        cycleCounter <= cycleCounter + 1;
        trapController.csrFile.increment_cycle_counter;
    endrule

    method Action start;
        if (hartState == RESET) begin
            stateTransitionQueue.enq(STARTING);
        end
    endmethod

    method HARTState getState;
        return hartState;
    endmethod

    interface Get getInstructionMemoryRequest = fetchUnit.getInstructionMemoryRequest;
    interface Put putInstructionMemoryResponse = fetchUnit.putInstructionMemoryResponse;

    interface TileLinkLiteWordClient dataMemoryClient = memoryAccessUnit.dataMemoryClient;
    interface Put putPipeliningEnabled = toPut(asIfc(pipeliningEnabled));

    interface Debug debug;
        method Word readGPR(RVGPRIndex idx);
            return 0;
        endmethod

        method Action writeGPR(RVGPRIndex idx, Word newValue);
        endmethod

        method Maybe#(Word) readCSR(RVCSRIndex idx);
            return tagged Invalid;
        endmethod

        method Action writeCSR(RVCSRIndex idx, Word newValue);
        endmethod

        method Action halt();
            changeState(HALTING);
        endmethod

        method Action resume();
            changeState(RESUMING);
        endmethod

        method Action step();
            changeState(STEPPING);
        endmethod
    endinterface

    interface Get getMemoryAccess = memoryAccessUnit.getMemoryAccess;

`ifdef ENABLE_RISCOF_TESTS
    interface Get getRISCOFHaltRequested = writebackUnit.getRISCOFHaltRequested;
`endif    

endmodule
