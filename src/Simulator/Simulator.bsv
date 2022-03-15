import PGTypes::*;
import DebugModule::*;
import ProgramMemoryTile::*;
import ReadOnly::*;
import SimSoCMap::*;

import Connectable::*;
import Core::*;
import GetPut::*;
import RegFile::*;

(* synthesize *)
module mkSimulator(Empty);
    SimSoCMap socMap <- mkSimSoCMap;
    ProgramMemoryTile memory <- mkProgramMemoryTile(socMap.ram0Id);

    ReadOnly#(Maybe#(Word)) toHostAddress <- mkReadOnly(tagged Valid 'h8000_1000);

`ifdef DISABLE_PIPELINING
    ReadOnly#(Bool) enablePipelining <- mkReadOnly(False);
`else
    ReadOnly#(Bool) enablePipelining <- mkReadOnly(True);
`endif

    // Core
    ProgramCounter initialProgramCounter = socMap.ram0Base;
    Core core <- mkCore(initialProgramCounter);

    mkConnection(memory.portA, core.systemMemoryBusClient);
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
