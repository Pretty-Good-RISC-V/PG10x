import PGTypes::*;

import GetPut::*;

typedef Bit#(3) DebugModeCause;
DebugModeCause dcause_EBREAK        = 3'h01;
DebugModeCause dcause_TRIGGER       = 3'h02;
DebugModeCause dcause_HALTREQUESTED = 3'h03;
DebugModeCause dcause_SINGLESTEP    = 3'h04;
DebugModeCause dcause_RESETHALT     = 3'h05;
DebugModeCause dcause_HALTGROUP     = 3'h06;

interface DebugControlAndStatus;
    method Action write(Word value);
    method ActionValue#(Word) read;

    interface Put#(Bool) putSingleStepEnabled;
    interface Get#(Bool) getSingleStepEnabled;
endinterface

module mkDebugControlAndStatus(DebugControlAndStatus);
    Reg#(Bool) stepie <- mkReg(False);                  // Interrupts enabled (including NMI) in during single step.
    Reg#(Bool) stopcount <- mkReg(False);               // Stop counters while in debug mode
    Reg#(Bool) stoptime <- mkReg(False);                // Stop timers while in debug mode
    Reg#(DebugModeCause) cause <- mkReg(0);             // Cause for entering debug mode
    Reg#(Bool) nmip <- mkReg(False);                    // NMI Pending upon entering debug mode
    Reg#(Bool) step <- mkReg(False);                    // Single step enabled
    Reg#(RVPrivilegeLevel) prv <- mkReg(priv_MACHINE);  // Privilege Level upon entering debug mode

    method Action write(Word value);
        stepie <= unpack(value[11]);
        stopcount <= unpack(value[10]);
        stoptime <= unpack(value[9]);
        cause <= unpack(value[8:6]);
        nmip <= unpack(value[3]);
        step <= unpack(value[2]);
        prv <= unpack(value[1:0]);
    endmethod

    method ActionValue#(Word) read;
        return {
            4'h04,          // Debug support exists and matches debug spec.
            10'h0,          // RESERVED
            1'b0,           // ebreakvs
            1'b0,           // ebreakvm
            1'b0,           // ebreamm
            1'b0,           // RESERVED
            1'b0,           // ebreaks
            1'b0,           // ebreaku
            pack(stepie),   // stepie
            pack(stopcount),// stopcount
            pack(stoptime), // stoptime
            pack(cause),    // cause
            1'b0,           // v
            1'b0,           // mprven
            pack(nmip),     // nmpi
            pack(step),     // step
            pack(prv)       // prv
        };
    endmethod

    interface Put putSingleStepEnabled;
        method Action put(Bool value);
            step <= value;
        endmethod
    endinterface
    interface Get getSingleStepEnabled = toGet(step);
endmodule
