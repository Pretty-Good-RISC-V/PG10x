import PGTypes::*;
import Core::*;
import Crossbar::*;
import ROMTile::*;
import SoCMap::*;
import TileLink::*;

interface SoC;
endinterface

(* synthesize *)
module mkSoC(SoC);
    // SoCMap
    SoCMap socMap <- mkSoCMap;

    // ROM
    ROMTile rom <- mkROMTile(socMap.rom0Id);

    // Crossbar
    Crossbar crossbar <- mkCrossbar(socMap.crossbarId);

    // Core
    ProgramCounter initialProgramCounter = socMap.rom0Base;
    Core core <- mkCore(initialProgramCounter);
endmodule
