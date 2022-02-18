import PGTypes::*;

import CSRFile::*;
import DebugModule::*;
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
    method Action start();
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
        DebugModule debugModule,
        ProgramCounter initialProgramCounter,
        InstructionMemoryServer instructionMemory,
        DataMemoryServer dataMemory,
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
    // CSR (Control and Status Register) file
    //
    CSRFile csrFile <- mkCSRFile();

    //
    // Register file
    //
    RegisterFile registerFile <- mkRegisterFile();

    //
    // Scoreboard
    //
    Scoreboard#(4) scoreboard <- mkScoreboard;

    //
    // Exception controller
    //
    ExceptionController exceptionController <- mkExceptionController(csrFile);

    //
    // Pipeline stage epochs
    //
    PipelineController pipelineController <- mkPipelineController(6 /* stage count */);

    //
    // Program Counter Redirect
    //
    ProgramCounterRedirect programCounterRedirect <- mkProgramCounterRedirect;

    //
    // Current privilege level
    //
    Reg#(RVPrivilegeLevel) currentPrivilegeLevel <- mkReg(PRIVILEGE_LEVEL_MACHINE);

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
        fetchUnit.getEncodedInstructionQueue,
        scoreboard,
        registerFile
    );

    //
    // Stage 3 - Instruction execution
    //
    ExecutionUnit executionUnit <- mkExecutionUnit(
        cycleCounter,
        3,  // stage number
        pipelineController,
        decodeUnit.getDecodedInstructionQueue,
        programCounterRedirect,
        currentPrivilegeLevel,
        csrFile,
        halt
    );

    //
    // Stage 4 - Memory access
    //
    MemoryAccessUnit memoryAccessUnit <- mkMemoryAccessUnit(
        cycleCounter,
        4,
        pipelineController,
        executionUnit.getExecutedInstructionQueue,
`ifdef MONITOR_TOHOST_ADDRESS
        dataMemory,
        toHostAddress
`else
        dataMemory
`endif
    );

    // 
    // Stage 5 - Register Writeback
    //
    WritebackUnit writebackUnit <- mkWritebackUnit(
        cycleCounter,
        5,
        pipelineController,
        memoryAccessUnit.getMemoryAccessedInstructionQueue,
        programCounterRedirect,
        scoreboard,
        registerFile,
        csrFile,
        exceptionController,
        currentPrivilegeLevel
    );

    //
    // State handlers
    //
    // RESET,          // -> STARTING
    // STARTING,       // -> RUNNING
    // RUNNING,        // -> HALTING
    // HALTING,        // -> HALTED
    // HALTED,         // -> RESUMING
    // RESUMING        // -> RUNNING
    FIFO#(CoreState) stateTransitionQueue <- mkFIFO();

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
        $display("CPU HALTED. Cycles: %0d - Instructions retired: %0d", csrFile.cycle_counter, csrFile.instructions_retired_counter);
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
        csrFile.increment_cycle_counter();
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
