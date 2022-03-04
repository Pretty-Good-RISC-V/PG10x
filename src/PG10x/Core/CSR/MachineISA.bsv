import PGTypes::*;

interface MachineISA;
    method Word read;
    method Action write(Word value);
endinterface

module mkMachineISARegister(MachineISA);
    method Word read;
        Word result = 0;
`ifdef RV32
        result[31:30] = 'b01;
`elsif RV64
        result[63:62] = 'b01;
`endif
        result[25:0] = isaext_I;
        return result;
    endmethod

    method Action write(Word value);
    endmethod
endmodule
