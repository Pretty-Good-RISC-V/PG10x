import PGTypes::*;
import Core::*;
import Crossbar::*;
import SoCMap::*;
import SoCAddressMap::*;
import TileLink::*;

interface SoC;
endinterface

(* synthesize *)
module mkSoC(SoC);
    // SoCMap
    SoCAddressMap socMap <- mkSoCAddressMap;

    // Crossbar
    Crossbar crossbar <- mkCrossbar(socMap);

    // Core
    ProgramCounter initialProgramCounter = socMap.rom0Base;
    Core core <- mkCore(initialProgramCounter);
endmodule
