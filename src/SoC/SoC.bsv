import PGTypes::*;
import Core::*;
import Crossbar::*;
import SoCMap::*;

interface SoC;
endinterface

(* synthesize *)
module mkSoC(SoC);
    // SoCMap
    SoCMap socMap <- mkSoCMap;

    // Crossbar
    Crossbar crossbar <- mkCrossbar(socMap.crossbarId);

    // Core
    ProgramCounter initialProgramCounter = socMap.rom0Base;
    Core core <- mkCore(initialProgramCounter);
endmodule
