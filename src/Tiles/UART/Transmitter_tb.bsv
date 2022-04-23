import BaudGenerator::*;
import Transmitter::*;

import Cntrs::*;
import Connectable::*;
import GetPut::*;

Integer clockRate = 12_000_000;
Integer baudRate  = 115_200;

interface Transmitter_tb;
    (* always_ready, always_enabled *)
    interface Get#(Bit#(1)) get_tx;
endinterface

(* synthesize *)
module mkTransmitter_tb(Transmitter_tb);
    BaudGenerator baudGenerator <- mkBaudGenerator(clockRate / baudRate);
    Transmitter transmitter <- mkTransmitter;

    mkConnection(baudGenerator.getBaudX2Ticked, transmitter.putBaudX2Ticked);

    UCount cycleCounter <- mkUCount(0, clockRate - 1);

    interface Get get_tx = transmitter.get_tx;
endmodule
