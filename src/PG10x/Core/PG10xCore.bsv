import PGTypes::*;

import DecodeUnit::*;
import ExceptionController::*;
import ExecutionUnit::*;
import FetchUnit::*;
import MemoryAccessUnit::*;
import MemoryInterfaces::*;
import PipelineController::*;
import ProgramCounterRedirect::*;
import RegisterFile::*;
import Scoreboard::*;
import WritebackUnit::*;

import Connectable::*;
import FIFO::*;
import FIFOF::*;
import SpecialFIFOs::*;

// ================================================================
// Exports
export CoreState(..), PG100Core (..), mkPG100Core;

//
// CoreState - roughy follows the RISC-V debug spec for hart states.
//
typedef enum {
    RESET,          // -> STARTING
    STARTING,       // -> RUNNING
    RUNNING,        // -> HALTING
    HALTING,        // -> HALTED
    HALTED,         // -> RESUMING
    RESUMING        // -> RUNNING
} CoreState deriving(Bits, Eq, FShow);

interface PG100Core;
    method Action start;
    method CoreState state;
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
module mkPG100Core#(
        ProgramCounter initialProgramCounter,
        TileLinkLiteWordServer instructionMemory,
        TileLinkLiteWordServer dataMemory,
`ifdef MONITOR_TOHOST_ADDRESS
        Word toHostAddress,
`endif
        Bool disablePipelining
)(PG100Core);
    //
    // CoreState
    //
    Reg#(CoreState) coreState <- mkReg(RESET);

    //
    // Cycle counter
    //
    Reg#(Word64) cycleCounter <- mkReg(0);

    //
    // CPU Halt Flag
    //
    Reg#(Bool) halt <- mkReg(False);

    //
    // Register file
    //
    RegisterFile registerFile <- mkRegisterFile;

    //
    // Scoreboard
    //
    Scoreboard#(4) scoreboard <- mkScoreboard;

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
        instructionMemory,
        fetchEnabled
    );

    //
    // Stage 2 - Instruction Decode
    //
    DecodeUnit decodeUnit <- mkDecodeUnit(
        cycleCounter,
        2,  // stage number
        pipelineController,
        scoreboard,
        registerFile
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
        pipelineController,
`ifdef MONITOR_TOHOST_ADDRESS
        dataMemory,
        toHostAddress
`else
        dataMemory
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
        scoreboard,
        registerFile,
        exceptionController
    );

    mkConnection(memoryAccessUnit.getExecutedInstruction, writebackUnit.putExecutedInstruction);

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
    FIFO#(CoreState) stateTransitionQueue <- mkFIFO;

    rule handleStartingState(coreState == STARTING);
        stateTransitionQueue.enq(RUNNING);
    endrule

    Reg#(Bool) firstRun <- mkReg(True);
    rule handleRunningState(coreState == RUNNING);
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

    rule handleHaltingState(coreState == HALTING);
        stateTransitionQueue.enq(HALTED);
    endrule

    rule handleHaltedState(coreState == HALTED);
        $display("CPU HALTED. Cycles: %0d - Instructions retired: %0d", exceptionController.csrFile.cycle_counter, exceptionController.csrFile.instructions_retired_counter);
        $finish();
    endrule

    rule handleResumingState(coreState == RESUMING);
        stateTransitionQueue.enq(RUNNING);
    endrule

    (* fire_when_enabled *)
    rule handleStateTransition;
        let newState = stateTransitionQueue.first;
        stateTransitionQueue.deq;

        coreState <= newState;
    endrule

    (* fire_when_enabled, no_implicit_conditions *)
    rule incrementCycleCounter;
        cycleCounter <= cycleCounter + 1;
        exceptionController.csrFile.increment_cycle_counter;
    endrule

    method Action start;
        if (coreState == RESET) begin
            stateTransitionQueue.enq(STARTING);
        end
    endmethod

    method CoreState state;
        return coreState;
    endmethod
endmodule
