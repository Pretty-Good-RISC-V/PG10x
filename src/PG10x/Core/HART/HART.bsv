import PGTypes::*;

import Debug::*;
import DecodeUnit::*;
import ExceptionController::*;
import ExecutionUnit::*;
import FetchUnit::*;
import GPRFile::*;
import MemoryAccessUnit::*;
import PipelineController::*;
import ProgramCounterRedirect::*;
import TileLink::*;
import WritebackUnit::*;

import Connectable::*;
import FIFO::*;
import FIFOF::*;
import GetPut::*;
import SpecialFIFOs::*;

// ================================================================
// Exports
export HARTState(..), HART (..), mkHART;

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
    method HARTState state;

    interface TileLinkLiteWordClient#(XLEN) instructionMemoryClient;
    interface TileLinkLiteWordClient#(XLEN) dataMemoryClient;

    interface Put#(ProgramCounter) putInitialProgramCounter;
    interface Put#(Bool) putPipeliningDisabled;
    interface Put#(Maybe#(Word)) putToHostAddress;

    interface Debug debug;
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
    Reg#(Bool) forcePipeliningDisabled <- mkReg(False); // External pipeline control
    Reg#(Bool) pipeliningDisabled <- mkReg(False);      // Internal pipeline enable/disable
    Reg#(Maybe#(Word)) toHostAddress <- mkReg(tagged Invalid);

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
    // Exception controller (and CSRFile)
    //
    ExceptionController exceptionController <- mkExceptionController;

    //
    // Pipeline stage epochs
    //
    PipelineController pipelineController <- mkPipelineController(6 /* stage count */);

    //
    // Program Counter Redirect
    //
    ProgramCounterRedirect programCounterRedirect <- mkProgramCounterRedirect;

    //
    // Program Counter
    //
    Reg#(ProgramCounter) programCounter <- mkReg(initialProgramCounter);

    //
    // Stage 1 - Instruction fetch
    //
    Reg#(Bool) fetchEnabled <- mkReg(False);
    FetchUnit fetchUnit <- mkFetchUnit(
        1,  // stage number
        programCounter,
        programCounterRedirect
    );

    mkConnection(toGet(cycleCounter), fetchUnit.putCycleCounter);
    mkConnection(toGet(fetchEnabled), fetchUnit.putFetchEnabled);

    //
    // Stage 2 - Instruction Decode
    //
    DecodeUnit decodeUnit <- mkDecodeUnit(
        2,  // stage number
        pipelineController,
        gprFile
    );

    mkConnection(toGet(cycleCounter), decodeUnit.putCycleCounter);
    mkConnection(fetchUnit.getEncodedInstruction, decodeUnit.putEncodedInstruction);

    //
    // Stage 3 - Instruction execution
    //
    ExecutionUnit executionUnit <- mkExecutionUnit(
        3,  // stage number
        pipelineController,
        programCounterRedirect,
        exceptionController
    );

    mkConnection(toGet(cycleCounter), executionUnit.putCycleCounter);
    mkConnection(decodeUnit.getDecodedInstruction, executionUnit.putDecodedInstruction);
    mkConnection(executionUnit.getGPRBypassValue, decodeUnit.putGPRBypassValue1);
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
    mkConnection(memoryAccessUnit.getGPRBypassValue, decodeUnit.putGPRBypassValue2);

    // 
    // Stage 5 - Register Writeback
    //
    WritebackUnit writebackUnit <- mkWritebackUnit(
        5,
        pipelineController,
        programCounterRedirect,
        gprFile,
        exceptionController
    );

    mkConnection(toGet(cycleCounter), writebackUnit.putCycleCounter);
    mkConnection(memoryAccessUnit.getExecutedInstruction, writebackUnit.putExecutedInstruction);

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
    rule handleRunningState(hartState == RUNNING);
        if (firstRun) begin
            $display("FetchIndex,Cycle,Pipeline Epoch,Program Counter,Stage Number,Stage Name,Info");

            fetchEnabled <= True;
            firstRun <= False;
        end

        if ((forcePipeliningDisabled || pipeliningDisabled) && !firstRun) begin
            let wasRetired = writebackUnit.wasInstructionRetired;
            if (wasRetired) begin
                fetchEnabled <= True;
            end else begin
                fetchEnabled <= False;
            end
        end
    endrule

    //
    // HALTING
    //
    rule handleHaltingState(hartState == HALTING);
        fetchEnabled <= False;
        pipeliningDisabled <= True;

        // Wait for the pipeline to flush
        if (haltDelay > 0) begin
            haltDelay <= haltDelay - 1;
        end else begin
            changeState(HALTED);
        end
    endrule

    //
    // HALTED
    //
    // rule handleHaltedState(hartState == HALTED);
    // endrule

    //
    // RESUMING
    //
    rule handleResumingState(hartState == RESUMING);
        fetchEnabled <= True;
        pipeliningDisabled <= False;
        changeState(RUNNING);
    endrule

    //
    // STEPPING
    //
    rule handleSteppingState(hartState == STEPPING);
        fetchEnabled <= True;   // For a single cycle
        changeState(HALTING);
    endrule
    //
    // QUITTING
    //
    rule handleQuittingState(hartState == QUITTING);
        $display("CPU HALTED. Cycles: %0d - Instructions retired: %0d", exceptionController.csrFile.cycle_counter, exceptionController.csrFile.instructions_retired_counter);
        $finish();
    endrule

    (* fire_when_enabled *)
    rule handleStateTransition;
        let newState = stateTransitionQueue.first;
        stateTransitionQueue.deq;

        hartState <= newState;
    endrule

    (* fire_when_enabled, no_implicit_conditions *)
    rule incrementCycleCounter;
        cycleCounter <= cycleCounter + 1;
        exceptionController.csrFile.increment_cycle_counter;
    endrule

    method Action start;
        if (hartState == RESET) begin
            stateTransitionQueue.enq(STARTING);
        end
    endmethod

    method HARTState state;
        return hartState;
    endmethod

    interface TileLinkLiteWordClient instructionMemoryClient = fetchUnit.instructionMemoryClient;
    interface TileLinkLiteWordClient dataMemoryClient = memoryAccessUnit.dataMemoryClient;

    interface Put putInitialProgramCounter = toPut(asIfc(programCounter));
    interface Put putPipeliningDisabled = toPut(asIfc(forcePipeliningDisabled));
    interface Put putToHostAddress = memoryAccessUnit.putToHostAddress;

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
endmodule
