//
// RegisterFile
//
// This module contains a standard RISC-V general purpose register file with dual read ports.
//
import PGTypes::*;
import RegFile::*;

interface GPRFile;
    method Word read1(RVGPRIndex index);
    method Word read2(RVGPRIndex index);
    method Action write(RVGPRIndex index, Word value);
endinterface

(* synthesize *)
module mkGPRFile(GPRFile);
    RegFile#(RVGPRIndex, Word) regfile <- mkRegFileFull;

    method Word read1(RVGPRIndex index);
        return (index == 0 ? 0 : regfile.sub(index));
    endmethod

    method Word read2(RVGPRIndex index);
        return (index == 0 ? 0 : regfile.sub(index));
    endmethod

    method Action write(RVGPRIndex index, Word value);
        if (index != 0) begin
            regfile.upd(index, value);
        end
    endmethod
endmodule
