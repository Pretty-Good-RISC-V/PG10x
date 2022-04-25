import BaudGenerator::*;
import Transmitter::*;

import Cntrs::*;
import Connectable::*;
import GetPut::*;

Integer baudRate  = 115_200;

`ifdef ENABLE_SIMULATION
Integer clockRate = baudRate * 32;
interface Transmitter_tb;
endinterface
`else
Integer clockRate = 12_000_000;
interface Transmitter_tb;
    (* always_ready, always_enabled *)
    interface Get#(Bit#(1)) get_tx;

    (* always_ready, always_enabled *)
    interface Get#(Bool) get_tick;
endinterface
`endif

(* synthesize *)
module mkTransmitter_tb(Transmitter_tb);
    BaudGenerator baudGenerator <- mkBaudGenerator((clockRate / baudRate) * 16);
    Transmitter transmitter <- mkTransmitter;

    mkConnection(baudGenerator.getBaudX2Ticked, transmitter.putBaudX2Ticked);

    UCount cycleCounter <- mkUCount(0, clockRate - 1);
    Reg#(Bit#(3)) writeOffset <- mkReg(0);

    rule countdown;
        cycleCounter.incr(1);
        baudGenerator.clockTicked;
        if (cycleCounter.isEqual(clockRate - 1)) begin
            let data = 8'd65 + extend(writeOffset); 
            transmitter.putData.put(data);
            writeOffset <= writeOffset + 1;
        end
    endrule

`ifndef ENABLE_SIMULATION
    interface Get get_tx = transmitter.get_tx;
    interface Get get_tick = baudGenerator.getBaudX16Ticked;
`endif
endmodule
