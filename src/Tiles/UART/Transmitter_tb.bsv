import BaudGenerator::*;
import Transmitter::*;

import Cntrs::*;
import Connectable::*;
import GetPut::*;

`ifdef ENABLE_SIMULATION
Integer baudRate  = 115_200;
Integer clockRate = 22_115_384;
// Integer baudRate  = 1;
// Integer clockRate = baudRate * 32;
interface Transmitter_tb;
endinterface
`else
Integer baudRate  = 115_200;
Integer clockRate = 22_115_380;
interface Transmitter_tb;
    (* always_ready, always_enabled *)
    interface Get#(Bit#(1)) get_tx;

    (* always_ready, always_enabled *)
    method Clock get_clock;

    (* always_ready, always_enabled *)
    interface Get#(Bool) get_baudx16;

    (* always_ready, always_enabled *)
    interface Get#(Bool) get_baudx2;
endinterface
`endif

(* synthesize *)
module mkTransmitter_tb(Transmitter_tb);
    let clocksPerBaudX16 = (clockRate / baudRate) / 16;
    BaudGenerator baudGenerator <- mkBaudGenerator(clocksPerBaudX16);
    Transmitter transmitter <- mkTransmitter;

    mkConnection(baudGenerator.getBaudX2Ticked, transmitter.putBaudX2Ticked);

    UCount cycleCounter <- mkUCount(0, clockRate - 1);
    Reg#(Bit#(3)) writeOffset <- mkReg(0);

    rule countdown;
        $display("clocksPerBaudX16: %0d", fromInteger(clocksPerBaudX16));
        cycleCounter.incr(1);
        baudGenerator.clockTicked;
        if (cycleCounter.isEqual(0)) begin
            let data = 8'd65 + extend(writeOffset); 
            $display("Sending character: %c", data);
            transmitter.putData.put(data);
            writeOffset <= writeOffset + 1;
        end
    endrule

`ifndef ENABLE_SIMULATION
    let currentClock <- exposeCurrentClock;
    method Clock get_clock;
        return currentClock;
    endmethod

    interface Get get_tx = transmitter.get_tx;
    interface Get get_baudx16 = baudGenerator.getBaudX16Ticked;
    interface Get get_baudx2 = baudGenerator.getBaudX2Ticked;

`endif
endmodule
