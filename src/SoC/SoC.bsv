import PGTypes::*;
import Core::*;
import Crossbar::*;
import SoCMap::*;
import SoCAddressMap::*;
import SPIController::*;
import TileLink::*;

import GetPut::*;

interface SoC;
    (* always_ready, always_enabled *)
    interface Get#(Bool) getHeartBeat;
endinterface

(* synthesize *)
module mkSoC#(
    Clock peripheral_clock_12mhz
)(SoC);
    // SoCMap
    SoCAddressMap socMap <- mkSoCAddressMap;

    // Crossbar
    Crossbar crossbar <- mkCrossbar(socMap);

    // Core
    ProgramCounter initialProgramCounter = socMap.rom0Base;
    Core core <- mkCore(initialProgramCounter);

    Reg#(Bool) heartBeat    <- mkReg(False);
    Reg#(Word) cycleCounter <- mkReg(0);

    rule pulse;
        if (cycleCounter > 100_000_000) begin
            heartBeat <= !heartBeat;
            cycleCounter <= 0;
        end else begin
            cycleCounter <= cycleCounter + 1;
        end
    endrule

    interface Get getHeartBeat = toGet(heartBeat);
endmodule
