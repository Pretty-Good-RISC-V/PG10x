import PGTypes::*;
import Core::*;
import Crossbar::*;
import SoCMap::*;
import SoCAddressMap::*;
import SPIController::*;
import TileLink::*;
import UARTTile::*;

import Clocks::*;
import GetPut::*;

interface SoC;
    (* always_ready, always_enabled, prefix="heartbeat" *)
    interface Get#(Bit#(1)) get_heart_beat;

    (* always_ready, always_enabled, prefix="uart0_tx" *)
    interface Get#(Bit#(1)) get_uart0_tx;

    (* always_ready, always_enabled, prefix="uart0_rx" *)
    interface Put#(Bit#(1)) put_uart0_rx;
endinterface

(* synthesize *)
module mkSoC#(
    Clock peripheral_clock_12mhz
)(SoC);
    let socReset <- exposeCurrentReset;

    // SoCMap
    SoCAddressMap socMap <- mkSoCAddressMap;

    // Crossbar
    Crossbar crossbar <- mkCrossbar(socMap);

    // Core
    ProgramCounter initialProgramCounter = socMap.rom0Base;
    Core core <- mkCore(initialProgramCounter);

    // UART0
    GatedClockIfc uart0Clock <- mkGatedClock(True, peripheral_clock_12mhz);
    Reset uart0Reset <- mkAsyncResetFromCR(5, uart0Clock.new_clk);
    UARTTile#(TileIdSize, TileIdSize, XLEN) uart0 <- mkUARTTile(
        socMap.uart0Id, 
        uart0Clock.new_clk, 
        uart0Reset, 
        valueOf(TileIdSize), 
        valueOf(XLEN)
    );

    Reg#(Bit#(1)) heartBeat     <- mkReg(0);
    Reg#(Word) cycleCounter     <- mkReg(0);

    rule pulse;
        if (cycleCounter > 100_000_000) begin
            heartBeat <= ~heartBeat;
            cycleCounter <= 0;
        end else begin
            cycleCounter <= cycleCounter + 1;
        end
    endrule

    Reg#(Bit#(1)) uart0_tx      <- mkReg(0);
    Reg#(Bit#(1)) uart0_rx      <- mkReg(0);

    interface Get get_heart_beat = toGet(heartBeat);
    interface Get get_uart0_tx = toGet(uart0_tx);
    interface Put put_uart0_rx = toPut(asIfc(uart0_rx));
endmodule
