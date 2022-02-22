import PGTypes::*;
import ProgramMemoryTile::*;
import MemorySystem::*;

import RegFile::*;
import PG10xCore::*;
import MemorySystem::*;

(* synthesize *)
module mkSimulator(Empty);
    ProgramMemoryTile memory <- mkProgramMemoryTile();

    // Memory System
    let memoryBaseAddress = 'h80000000;
    MemorySystem memorySystem <- mkMemorySystem(memory, memoryBaseAddress);

    // Core
    PG100Core core <- mkPG100Core(
        'h8000_0000, 
        memorySystem.instructionMemory, 
        memorySystem.dataMemory,
`ifdef MONITOR_TOHOST_ADDRESS
        'h8000_1000,
`endif
        True // Disable Pipelining
    );
    Reg#(Bool) initialized <- mkReg(False);

    (* fire_when_enabled *)
    rule initialization(initialized == False && core.state == RESET);
        initialized <= True;

        $display("----------------");
        $display("RG-100 Simulator");
        $display("----------------");

        core.start();
    endrule
endmodule
