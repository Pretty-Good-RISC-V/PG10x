import PGTypes::*;
import Core::*;
import Crossbar::*;
import SoCMap::*;
import SoCAddressMap::*;
import SPIController::*;
import TileLink::*;

interface SoC;
endinterface

(* synthesize *)
module mkSoC#(
    Clock peripheralClock
)(SoC);
    // SoCMap
    SoCAddressMap socMap <- mkSoCAddressMap;

    // Crossbar
    Crossbar crossbar <- mkCrossbar(socMap);

    // Core
    ProgramCounter initialProgramCounter = socMap.rom0Base;
    Core core <- mkCore(initialProgramCounter);
endmodule
