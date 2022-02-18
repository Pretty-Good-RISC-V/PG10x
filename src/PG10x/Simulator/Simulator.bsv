import PGTypes::*;
import BRAMServerTile::*;
import MemorySystem::*;

import DebugModule::*;
import RegFile::*;
import PG10xCore::*;
import MemorySystem::*;

(* synthesize *)
module mkSimulator(Empty);
    // BRAM Server Tile
    DualPortBRAMServerTile memory <- mkBRAMServerTileFromFile(32, "MemoryContents.hex");

    // Memory System
    let memoryBaseAddress = 'h80000000;
    MemorySystem memorySystem <- mkMemorySystem(memory, memoryBaseAddress);

    // Debug Module
    DebugModule debugModule <- mkDebugModule();

    // Core
    PG100Core core <- mkPG100Core(
        debugModule, 
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
