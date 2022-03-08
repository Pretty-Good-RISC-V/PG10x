//
// RegisterFile
//
// This module contains a standard RISC-V register file with dual read ports.
//
import PGTypes::*;
import Vector::*;

interface GPRFile;
    method Word read1(RVGPRIndex index);
    method Word read2(RVGPRIndex index);
    method Action write(RVGPRIndex index, Word value);
endinterface

(* synthesize *)
module mkGPRFile(GPRFile);
    Vector#(32, Array#(Reg#(Word))) registers <- replicateM(mkCReg(2, 0));

    method Word read1(RVGPRIndex index);
        return registers[index][1];
    endmethod

    method Word read2(RVGPRIndex index);
        return registers[index][1];
    endmethod

    method Action write(RVGPRIndex index, Word value);
        if (index != 0) begin
            registers[index][0] <= value;
        end
    endmethod
endmodule
