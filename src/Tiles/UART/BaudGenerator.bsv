import Cntrs::*;
import GetPut::*;

interface BaudGenerator;
    method Action clockTicked;

    interface Get#(Bool) getBaudX2Ticked;
    interface Get#(Bool) getBaudX16Ticked;
endinterface

module mkBaudGenerator#(Integer ticksPer16xBaud)(BaudGenerator);
    // baudRateX16Counter - counts *clock* ticks until the X16 baud has been reached
    UCount baudRateX16Counter <- mkUCount(0, ticksPer16xBaud - 1);
    // baudRateX16        - pulses at baud rate * 16
    PulseWire baudRateX16 <- mkPulseWire;
    // baudRateX2Counter  - counts *rateX16* ticks until the X2 baud has been reached
    UCount baudRateX2Counter <- mkUCount(0, 7);
    // baudRateX2         - pulses at baud rate * 2
    PulseWire baudRateX2 <- mkPulseWire;

    method Action clockTicked;
        // See if the X16 counter has elapsed...
        if (baudRateX16Counter.isEqual(0)) begin
            baudRateX16.send;           // Pulse the X16 wire

            // See if the X2 counter has elapsed...
            if (baudRateX2Counter.isEqual(0)) begin
                baudRateX2.send;        // Pulse the X2 wire
            end

            baudRateX2Counter.incr(1);  // Increment the X2 counter
        end

        baudRateX16Counter.incr(1);     // Increment the X16 counter
    endmethod

    interface Get getBaudX2Ticked = toGet(baudRateX2);
    interface Get getBaudX16Ticked = toGet(baudRateX16);
endmodule
