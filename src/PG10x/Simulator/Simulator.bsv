import PGTypes::*;
import ProgramMemoryTile::*;
import MemorySystem::*;

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

    // HART
    HART hart <- mkHART(
        'h8000_0000, 
`ifdef MONITOR_TOHOST_ADDRESS
        'h8000_1000,
`endif

`ifdef DISABLE_PIPELINING
        True
`else
        False
`endif
    );

    mkConnection(memorySystem.instructionMemoryServer, hart.instructionMemoryClient);
    mkConnection(memorySystem.dataMemoryServer, hart.dataMemoryClient);

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

        hart.start;
    endrule
endmodule
