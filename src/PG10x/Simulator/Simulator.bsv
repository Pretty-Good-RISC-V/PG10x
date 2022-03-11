import PGTypes::*;
import DebugModule::*;
import MemorySystem::*;
import ProgramMemoryTile::*;
import ReadOnly::*;

import Connectable::*;
import RegFile::*;
import HART::*;
import MemorySystem::*;

(* synthesize *)
module mkSimulator(Empty);
    ProgramMemoryTile memory <- mkProgramMemoryTile;

    // Memory System
    let memoryBaseAddress = 'h80000000;
    MemorySystem memorySystem <- mkMemorySystem(memory, memoryBaseAddress);

    ReadOnly#(Maybe#(Word)) toHostAddress <- mkReadOnly(tagged Valid 'h8000_1000);
    ReadOnly#(Word) initialProgramCounter <- mkReadOnly('h8000_0000);

`ifdef DISABLE_PIPELINING
    ReadOnly#(Bool) enablePipelining <- mkReadOnly(False);
`else
    ReadOnly#(Bool) enablePipelining <- mkReadOnly(True);
`endif

    // HART
    HART hart <- mkHART();

    mkConnection(memorySystem.instructionMemoryServer, hart.instructionMemoryClient);
    mkConnection(memorySystem.dataMemoryServer, hart.dataMemoryClient);

    mkConnection(toGet(toHostAddress), hart.putToHostAddress);

    Reg#(Bool) initialized <- mkReg(False);

    (* fire_when_enabled *)
    rule initialization(initialized == False && hart.state == RESET);
        initialized <= True;

        $display("----------------");
`ifdef DISABLE_PIPELINING
        $display("RG-100 Simulator");
        $display("*Pipelining OFF*");
`else
        $display("RG-100 Simulator");
`endif
        $display("----------------");

        Bool breakOnStart <- $test$plusargs("debug");

        hart.start;
    endrule
endmodule
