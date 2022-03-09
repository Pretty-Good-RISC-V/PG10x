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
import SpecialFIFOs::*;

// ================================================================
// Exports
export HARTState(..), HART (..), mkHART;

//
// HARTState - roughy follows the RISC-V debug spec for hart states.
//
typedef enum {
    RESET,          // -> STARTING
    STARTING,       // -> RUNNING
    RUNNING,        // -> HALTING
    HALTING,        // -> HALTED
    HALTED,         // -> RESUMING
    RESUMING        // -> RUNNING
} HARTState deriving(Bits, Eq, FShow);

interface HART;
    method Action start;
    method HARTState state;

    interface TileLinkLiteWordClient#(XLEN) instructionMemoryClient;
    interface TileLinkLiteWordClient#(XLEN) dataMemoryClient;

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
    ProgramCounter initialProgramCounter,
`ifdef MONITOR_TOHOST_ADDRESS
    Word toHostAddress,
`endif
    Bool disablePipelining
)(HART);
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
    // Stage 1 - Instruction fetch
    //
    Reg#(Bool) fetchEnabled <- mkReg(False);
    FetchUnit fetchUnit <- mkFetchUnit(
        cycleCounter,
        1,  // stage number
        initialProgramCounter,
        programCounterRedirect,
        fetchEnabled
    );

    //
    // Stage 2 - Instruction Decode
    //
    DecodeUnit decodeUnit <- mkDecodeUnit(
        cycleCounter,
        2,  // stage number
        pipelineController,
        gprFile
    );

    mkConnection(fetchUnit.getEncodedInstruction, decodeUnit.putEncodedInstruction);

    //
    // Stage 3 - Instruction execution
    //
    ExecutionUnit executionUnit <- mkExecutionUnit(
        cycleCounter,
        3,  // stage number
        pipelineController,
        programCounterRedirect,
        exceptionController,
        halt
    );

    mkConnection(decodeUnit.getDecodedInstruction, executionUnit.putDecodedInstruction);

    //
    // Stage 4 - Memory access
    //
    MemoryAccessUnit memoryAccessUnit <- mkMemoryAccessUnit(
        cycleCounter,
        4,
`ifdef MONITOR_TOHOST_ADDRESS
        pipelineController,
        toHostAddress
`else
        pipelineController
`endif
    );

    mkConnection(executionUnit.getExecutedInstruction, memoryAccessUnit.putExecutedInstruction);

    // 
    // Stage 5 - Register Writeback
    //
    WritebackUnit writebackUnit <- mkWritebackUnit(
        cycleCounter,
        5,
        pipelineController,
        programCounterRedirect,
        gprFile,
        exceptionController
    );

    mkConnection(memoryAccessUnit.getExecutedInstruction, writebackUnit.putExecutedInstruction);

    //
    // GPR Bypasses
    //
    mkConnection(executionUnit.getGPRBypassValue, decodeUnit.putGPRBypassValue1);
    mkConnection(memoryAccessUnit.getGPRBypassValue, decodeUnit.putGPRBypassValue2);

    //
    // State handlers
    //
    // RESET,          // -> STARTING
    // STARTING,       // -> RUNNING
    // RUNNING,        // -> HALTING
    // HALTING,        // -> HALTED
    // HALTED,         // -> RESUMING
    // RESUMING        // -> RUNNING
    //
    FIFO#(HARTState) stateTransitionQueue <- mkFIFO;

    rule handleStartingState(hartState == STARTING);
        stateTransitionQueue.enq(RUNNING);
    endrule

    Reg#(Bool) firstRun <- mkReg(True);
    rule handleRunningState(hartState == RUNNING);
        if (firstRun) begin
            $display("FetchIndex,Cycle,Pipeline Epoch,Program Counter,Stage Number,Stage Name,Info");

            fetchEnabled <= True;
            firstRun <= False;
        end

        if (disablePipelining && !firstRun) begin
            let wasRetired = writebackUnit.wasInstructionRetired;
            if (wasRetired) begin
                fetchEnabled <= True;
            end else begin
                fetchEnabled <= False;
            end
        end
    endrule

    rule handleHaltingState(hartState == HALTING);
        stateTransitionQueue.enq(HALTED);
    endrule

    rule handleHaltedState(hartState == HALTED);
        $display("CPU HALTED. Cycles: %0d - Instructions retired: %0d", exceptionController.csrFile.cycle_counter, exceptionController.csrFile.instructions_retired_counter);
        $finish();
    endrule

    rule handleResumingState(hartState == RESUMING);
        stateTransitionQueue.enq(RUNNING);
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

    interface TileLinkLiteWordClient instructionMemoryClient = fetchUnit.instructionMemoryClient;
    interface TileLinkLiteWordClient dataMemoryClient = memoryAccessUnit.dataMemoryClient;

    method Action start;
        if (hartState == RESET) begin
            stateTransitionQueue.enq(STARTING);
        end
    endmethod

    method HARTState state;
        return hartState;
    endmethod

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
        endmethod

        method Action resume();
        endmethod

        method Action step();
        endmethod
    endinterface
endmodule
