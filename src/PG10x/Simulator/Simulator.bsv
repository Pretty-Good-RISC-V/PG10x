import PGTypes::*;
import DebugModule::*;
import MemorySystem::*;
import ProgramMemoryTile::*;
import ReadOnly::*;

import Connectable::*;
import RegFile::*;
import PG10xCore::*;
import MemorySystem::*;

(* synthesize *)
module mkSimulator(Empty);
    ProgramMemoryTile memory <- mkProgramMemoryTile;

    // Memory System
    let memoryBaseAddress = 'h80000000;
    MemorySystem memorySystem <- mkMemorySystem(memory, memoryBaseAddress);

    ReadOnly#(Maybe#(Word)) toHostAddress <- mkReadOnly(tagged Valid 'h8000_1000);

`ifdef DISABLE_PIPELINING
    ReadOnly#(Bool) enablePipelining <- mkReadOnly(False);
`else
    ReadOnly#(Bool) enablePipelining <- mkReadOnly(True);
`endif

    // HART
    ProgramCounter initialProgramCounter = 'h8000_0000;
    PG10xCore core <- mkPG10xCore(initialProgramCounter);

    mkConnection(memorySystem.instructionMemoryServer, core.instructionMemoryClient);
    mkConnection(memorySystem.dataMemoryServer, core.dataMemoryClient);
    mkConnection(toGet(toHostAddress), core.putToHostAddress);

    Reg#(Bool) initialized <- mkReg(False);

    (* fire_when_enabled *)
    rule initialization(initialized == False && core.getState == RESET);
        initialized <= True;

        $display("----------------");
`ifdef DISABLE_PIPELINING
        $display("PG-10x Simulator");
        $display("*Pipelining OFF*");
`else
        $display("PG-10x Simulator");
`endif
        $display("----------------");

        core.start;
    endrule
endmodule
