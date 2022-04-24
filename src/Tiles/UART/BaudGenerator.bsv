import Cntrs::*;
import GetPut::*;

interface BaudGenerator;
    method Action clockTicked;

    interface Get#(Bool) getBaudX2Ticked;
    interface Get#(Bool) getBaudX16Ticked;
endinterface

module mkBaudGenerator#(Integer ticksPerClock)(BaudGenerator);
    UCount baudRateX2Counter <- mkUCount(0, 7);         // Counts baud ticks - pulses 'baudRateX2' when = 0
    PulseWire baudRateX2 <- mkPulseWire;                // Pulses at baud rate * 2

    UCount clockCounter <- mkUCount(0, (ticksPerClock / 2) - 1);  // Counts clock ticks
    PulseWire baudRateX16 <- mkPulseWire;               // Pulses at baud rate * 16

    rule baudTick16(baudRateX16);
        baudRateX2Counter.incr(1);
    endrule

    rule baudTick2(baudRateX2Counter.isEqual(0) && baudRateX16);
        baudRateX2.send;
    endrule

    method Action clockTicked;
        if (clockCounter.isEqual(0)) begin
            baudRateX16.send;
        end

        clockCounter.incr(1);
    endmethod

    interface Get getBaudX2Ticked = toGet(baudRateX2);
    interface Get getBaudX16Ticked = toGet(baudRateX16);
endmodule
