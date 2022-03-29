//
// Scoreboard
//
// This module is used to manage CSR register hazards.  When a destination CSR register is
// going to be written by an instruction, it writes that CSR register index into the scoreboard.
// Later instructions in the pipeline query the scoreboard to determine if they must stall
// waiting for the original register.
//
import PGTypes::*;
import Vector::*;

interface Scoreboard#(numeric type size);
    method Action insert(Maybe#(RVCSRIndex) dst);
    method Bool search(Maybe#(RVCSRIndex) s1);
    method Action remove;
    method Bit#(TAdd#(TLog#(size),1)) size;
endinterface

module mkScoreboard(Scoreboard#(size));
    Vector#(size, Array#(Reg#(Maybe#(RVCSRIndex)))) entries <- replicateM(mkCReg(2, Invalid));
    Reg#(Bit#(TAdd#(TLog#(size),1))) iidx <- mkReg(0);
    Reg#(Bit#(TAdd#(TLog#(size),1))) ridx <- mkReg(0);
    Reg#(Bit#(TAdd#(TLog#(size),1))) count[3] <- mkCReg(3, 0);
    
    function Bool dataHazard(Maybe#(RVCSRIndex) src1, Maybe#(RVCSRIndex) dst);
        return (isValid(dst) && ((isValid(src1) && unJust(dst)==unJust(src1))));
    endfunction

    method Action insert(Maybe#(RVCSRIndex) r) if (count[1] != fromInteger(valueOf(size)));
        entries[iidx][1]._write(r);
        iidx <= iidx == fromInteger(valueOf(size)) - 1 ? 0 : iidx + 1;
        count[1] <= count[1] + 1;
    endmethod

    method Bool search(Maybe#(RVCSRIndex) s1);
        Bit#(size) r = 0;
        for (Integer i = 0; i < valueOf(size); i = i + 1) begin
            r[i] = pack(dataHazard(s1, entries[i][1]._read()));
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
