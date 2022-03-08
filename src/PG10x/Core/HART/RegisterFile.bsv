//
// RegisterFile
//
// This module contains a standard RISC-V register file with dual read ports.
//
import PGTypes::*;
import Vector::*;

interface RegisterFile;
    method Word read1(RegisterIndex index);
    method Word read2(RegisterIndex index);
    method Action write(RegisterIndex index, Word value);
endinterface

(* synthesize *)
module mkRegisterFile(RegisterFile);
    Vector#(32, Array#(Reg#(Word))) registers <- replicateM(mkCReg(2, 0));

    method Word read1(RegisterIndex index);
        return registers[index][1];
    endmethod

    method Word read2(RegisterIndex index);
        return registers[index][1];
    endmethod

    method Action write(RegisterIndex index, Word value);
        if (index != 0) begin
            registers[index][0] <= value;
        end
    endmethod
endmodule
