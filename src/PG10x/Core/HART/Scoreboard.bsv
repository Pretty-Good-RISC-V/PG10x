//
// Scoreboard
//
// This module is used to manage how register hazards.  When a destination register is
// going to be written by an instruction, it writes that register index into the scoreboard.
// Later instructions in the pipeline query the scoreboard to determine if they must stall
// waiting for the original register.
//
import PGTypes::*;
import Vector::*;

interface Scoreboard#(numeric type size);
    method Action insert(Maybe#(RegisterIndex) dst);
    method Bool search(Maybe#(RegisterIndex) s1, Maybe#(RegisterIndex) s2);
    method Action remove;
    method Bit#(TAdd#(TLog#(size),1)) size;
endinterface

module mkScoreboard(Scoreboard#(size));
    Vector#(size, Array#(Reg#(Maybe#(RegisterIndex)))) entries <- replicateM(mkCReg(2, Invalid));
    Reg#(Bit#(TAdd#(TLog#(size),1))) iidx <- mkReg(0);
    Reg#(Bit#(TAdd#(TLog#(size),1))) ridx <- mkReg(0);
    Reg#(Bit#(TAdd#(TLog#(size),1))) count[3] <- mkCReg(3, 0);
    
    function Bool dataHazard(Maybe#(RegisterIndex) src1, Maybe#(RegisterIndex) src2, Maybe#(RegisterIndex) dst);
        return (isValid(dst) && ((isValid(src1) && unJust(dst)==unJust(src1)) ||
            (isValid(src2) && unJust(dst)==unJust(src2))));
    endfunction

    method Action insert(Maybe#(RegisterIndex) r) if (count[1] != fromInteger(valueOf(size)));
        entries[iidx][1]._write(r);
        iidx <= iidx == fromInteger(valueOf(size)) - 1 ? 0 : iidx + 1;
        count[1] <= count[1] + 1;
    endmethod

    method Bool search(Maybe#(RegisterIndex) s1, Maybe#(RegisterIndex) s2);
        Bit#(size) r = 0;
        for (Integer i = 0; i < valueOf(size); i = i + 1) begin
            r[i] = pack(dataHazard(s1, s2, entries[i][1]._read()));
        end
        return r != 0;
    endmethod

    method Action remove if (count[0] != 0);
        entries[ridx][0]._write(tagged Invalid);
        ridx <= ridx == fromInteger(valueOf(size)) - 1 ? 0 : ridx + 1;
        count[0] <= count[0] - 1;
    endmethod

    method Bit#(TAdd#(TLog#(size),1)) size = count[1];
endmodule
